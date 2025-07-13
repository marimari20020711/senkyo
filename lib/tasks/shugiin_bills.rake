namespace :scrape do
  desc "Scrape Shugiin bills (衆法・参法・閣法)"
  task shugiin_hp_bills: :environment do
    require "open-uri"
    require "nokogiri"

    sessions_map = {
      "閣法" => (211..217).to_a.reverse,
      "衆法" => (211..217).to_a.reverse,
      "参法" => (211..217).to_a.reverse,
      "予算" => (211..217).to_a.reverse,
      "条約" => (211..217).to_a.reverse,
      "承認" => (211..217).to_a.reverse,
      "承諾" => (211..217).to_a.reverse,
      "決算" => (211..217).to_a.reverse,
      "決議" => (211..217).to_a.reverse,
      "規則" => (211..217).to_a.reverse,
      "規程" => (211..217).to_a.reverse
    }

    sessions_map.each do |table_name, sessions|
      sessions.each do |session_number|
        session_url = "https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/kaiji#{session_number}.htm"
        puts "▶️ Fetching #{table_name} for 第#{session_number}回国会"

        begin
          html = URI.open(session_url).read
          doc = Nokogiri::HTML.parse(html)
        rescue OpenURI::HTTPError => e
          puts "⚠️ ページが存在しません: #{session_url} (#{e.message})"
          next
        end

        anchor_name = { "閣法" => "09", "衆法" => "05", "参法" => "06", "予算" => "07", "条約" => "08", "承認" =>"10", "承諾" =>"11", "決算" =>"13", "決議" => "17", "規則" =>"18", "規程" =>"19" }[table_name]
        anchor = doc.at_css("a[name=\"#{anchor_name}\"]")
        next unless anchor

        table = anchor.xpath("following-sibling::table").first
        next unless table

        headers = table.css("th").map { |th| th.text.strip }
        col_indexes = {
          session: headers.find_index { |h| h.include?("提出回次") },
          number: headers.find_index { |h| h.include?("番号") },
          title: headers.find_index { |h| h.include?("議案件名") },
          status: headers.find_index { |h| h.include?("審議状況") },
          progress: headers.find_index { |h| h.include?("経過情報") },
          body: headers.find_index { |h| h.include?("本文情報") }
        }

        table.css("tr")[1..].each do |tr|
          tds = tr.css("td")
          next if tds.empty?

          session = tds[col_indexes[:session]]&.text&.strip
          number = col_indexes[:number] ? tds[col_indexes[:number]]&.text&.strip : nil
          title = tds[col_indexes[:title]]&.text&.strip
          discussion_status = tds[col_indexes[:status]]&.text&.strip
          progress_href = tds[col_indexes[:progress]]&.at_css("a")&.[]("href")
          body_href = col_indexes[:body] ? tds[col_indexes[:body]]&.at_css("a")&.[]("href") : nil

          if progress_href
            data = fetch_shugiin_progress_data(session_url, progress_href)
            kind = data[:kind].presence || table_name
            group_names = data[:group_names]
            proposer_names = data[:proposer_names]
            agreeer_names = data[:agreeer_names]
            discussion_agree_groups = data[:discussion_agree_groups]
            discussion_disagree_groups = data[:discussion_disagree_groups]
          else
            kind = table_name
            group_names = proposer_names = agreeer_names = discussion_agree_groups = discussion_disagree_groups = []
          end

          kind_mapping = {
            "閣法" => "法律案（内閣提出）",
            "衆法" => "法律案（衆法）",
            "参法" => "参法律案（参法）",
            "決議" => "決議案",
            "規則" => "規則案",
            "規程" => "規程案"
          }
          kind = kind_mapping[kind] || kind

          bill = Bill.find_or_initialize_by(session: session, number: number, title: title)

          bill.session = session
          bill.number = number
          bill.discussion_status = discussion_status
          bill.kind = kind

          if body_href
            body_data = fetch_shugiin_body_data(session_url, body_href)
            bill.summary_link = body_data[:summary_link]
            bill.summary_text = body_data[:summary_text]
            bill.body_link = body_data[:body_link]
            # bill.body_text = body_data[:body_text]
          end

          bill.save!

          save_bill_supports(bill, group_names, proposer_names, agreeer_names, discussion_agree_groups, discussion_disagree_groups)
          puts "[#{kind}] Saved: #{session}-#{number}: #{title}"
        end
      end

      puts "Shugiin scraping complete."
    end
  end

  def fetch_shugiin_progress_data(session_url, href)
    progress_url = URI.join(session_url, href).to_s
    begin
      progress_html = URI.open(progress_url, "r:Shift_JIS:UTF-8").read
    rescue Encoding::UndefinedConversionError => e
      puts "⚠️ エンコーディングエラー: #{progress_url} (#{e.message}) → スキップ"
      return {
      kind: [],
      group_names: [],
      proposer_names: [],
      agreeer_names: [],
      discussion_agree_groups: [],
      discussion_disagree_groups: []
      }
    end
    progress_doc = Nokogiri::HTML(progress_html)
    tables = progress_doc.css("table")

    data = {}
    tables[0]&.css("tr")&.each do |row|
      th = row.at_css("td:first-child") || row.at_css("th")
      td = row.at_css("td:last-child")
      next unless th && td
      data[th.text.strip] = td.text.strip
    end

    data2 = {}
    if tables[1]&.css("tr")
        tables[1]&.css("tr")&.each do |row|
        tds = row.css("td")
        next unless tds.size == 2
        data2[tds[0].text.strip] = tds[1].text.strip
      end
    end

    {
      kind: data["議案種類"].to_s,
      group_names: data["議案提出会派"].to_s.split(/、|,|;/).map(&:strip),
      proposer_names: data2.fetch("議案提出者一覧", "").split(/、|,|;/).map { |s| s.strip.sub(/君\z/, "") },
      agreeer_names: data2.fetch("議案提出の賛成者", "").split(/、|,|;/).map { |s| s.strip.sub(/君\z/, "") },
      discussion_agree_groups: data["衆議院審議時賛成会派"].to_s.split(/、|,|;/).map(&:strip),
      discussion_disagree_groups: data["衆議院審議時反対会派"].to_s.split(/、|,|;/).map(&:strip)
    }
  end

  def fetch_shugiin_body_data(session_url, href)
    body_url = URI.join(session_url, href).to_s
    body_html = URI.open(body_url).read.encode("UTF-8", "Shift_JIS")
    body_doc = Nokogiri::HTML(body_html)

    summary_link = nil
    summary_text = nil
    body_link = nil
    body_text = nil

    youkou_link = body_doc.css("a").find { |a| a.text.include?("要綱") }
    if youkou_link
      summary_link = URI.join(body_url, youkou_link["href"]).to_s
      summary_doc = Nokogiri::HTML(URI.open(summary_link, "r:Shift_JIS:UTF-8"))
      h2 = summary_doc.at_css("h2#TopContents")
      if h2
        summary_text = ""
        node = h2
        while node = node.next_element
          break if node.name =~ /^h\d$/i || node.name == "div"
          summary_text << node.text.strip + "\n\n"
        end
      end
    end

    houan_link = body_doc.css("a").find { |a| a.text.include?("提出時法律案") }
    if houan_link
      body_link = URI.join(body_url, houan_link["href"]).to_s

      houan_body_doc = Nokogiri::HTML(URI.open(body_link, "r:Shift_JIS:UTF-8"))
      h2 = houan_body_doc.at_css("h2#TopContents")
      ps = h2.xpath("following-sibling::p")
      body_text = ps.map(&:text).join("\n\n")
    end

    {
      summary_link: summary_link,
      summary_text: summary_text,
      body_link: body_link,
      body_text: body_text
    }
  end

  def save_bill_supports(bill, group_names, proposer_names, agreeer_names, agree_groups, disagree_groups)
    group_names.each do |g_name|
      next if g_name.blank?
      group = Group.find_or_create_by(name: g_name)
      BillSupport.find_or_create_by(bill: bill, supportable: group, support_type: "propose")
    end

    proposer_names.each do |p_name|
      next if p_name.blank?
      normalized_name = p_name.delete(" ")
      politician = Politician.find_by(normalized_name: normalized_name)
      next if politician.nil?
      BillSupport.find_or_create_by(bill: bill, supportable: politician, support_type: "propose")
    end

    agreeer_names.each do |a_name|
      next if a_name.blank?
      normalized_name = a_name.delete(" ")
      politician = Politician.find_by(normalized_name: normalized_name)
      next if politician.nil?
      BillSupport.find_or_create_by(bill: bill, supportable: politician, support_type: "propose_agree")
    end

    agree_groups.each do |g_name|
      next if g_name.blank?
      group = Group.find_or_create_by(name: g_name)
      BillSupport.find_or_create_by!(bill: bill, supportable: group, support_type: "agree")
    end

    disagree_groups.each do |g_name|
      next if g_name.blank?
      group = Group.find_or_create_by(name: g_name)
      BillSupport.find_or_create_by!(bill: bill, supportable: group, support_type: "disagree")
    end
  end
end
