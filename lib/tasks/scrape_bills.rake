namespace :scrape do
  desc "Scrape bills (衆法・参法・閣法)"
  task bills: :environment do
    require "open-uri"
    require "nokogiri"

    base_url = "https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/menu.htm"

    index_html = URI.open(base_url).read
    index_doc = Nokogiri::HTML.parse(index_html)

    anchor_map = {
      "05" => "衆法",
      "06" => "参法",
      "09" => "閣法"
    }

    anchor_map.each do |anchor_id, kind|
      puts "Processing: #{kind}"

      anchor = index_doc.at_css("a[name=\"#{anchor_id}\"]")
      unless anchor
        puts "Anchor ##{anchor_id} not found."
        next
      end

      table = anchor.xpath("following-sibling::table").first
      unless table
        puts "No table found after anchor ##{anchor_id}."
        next
      end

      # テーブルヘッダに基づき列番号を特定
      headers = table.css("tr").first.css("th").map { |th| th.text.strip }
      col_indexes = {
        session: headers.index { |h| h.include?("提出回次") },
        number: headers.index { |h| h.include?("番号") },
        title: headers.index { |h| h.include?("議案件名") },
        status: headers.index { |h| h.include?("審議状況") },
        progress: headers.index { |h| h.include?("経過情報") },
        body: headers.index { |h| h.include?("本文情報") }
      }

      table.css("tr")[1..].each do |tr|
        tds = tr.css("td")
        next if tds.empty?

        session = tds[col_indexes[:session]]&.text&.strip
        number = tds[col_indexes[:number]]&.text&.strip
        title = tds[col_indexes[:title]]&.text&.strip
        discussion_status = tds[col_indexes[:status]]&.text&.strip
        progress_href = tds[col_indexes[:progress]]&.at_css("a")&.[]("href")
        body_href = tds[col_indexes[:body]]&.at_css("a")&.[]("href")

        group_names = []
        proposer_names = []
        agreeer_names = []
        discussion_agree_groups = []
        discussion_disagree_groups = []
        summary_link = nil
        summary_text = nil

        # 経過情報ページ
        if progress_href
          progress_url = URI.join(base_url, progress_href).to_s
          progress_html = URI.open(progress_url, "r:Shift_JIS:UTF-8").read
          progress_doc = Nokogiri::HTML.parse(progress_html)

          tables = progress_doc.css("table")

          # 進捗テーブル
          data = {}
          tables[0]&.css("tr")&.each do |row|
            th = row.at_css("td:first-child") || row.at_css("th")
            td = row.at_css("td:last-child")
            next unless th && td
            key = th.text.strip
            value = td.text.strip
            data[key] = value
          end

          # 提出者テーブル
          data2 = {}
          if tables[1]
            tables[1].css("tr").each do |row|
              tds_ = row.css("td")
              next unless tds_.size == 2
              key = tds_[0].text.strip
              value = tds_[1].text.strip
              data2[key] = value
            end
          end

          group_names = data["議案提出会派"].to_s.split(/、|,|;/).map(&:strip)
          proposer_names = data2["議案提出者一覧"].to_s.split(/、|,|;/).map{ |s| s.strip.sub(/君\z/, "") }
          agreeer_names = data2["議案提出の賛成者"].to_s.split(/、|,|;/).map{ |s| s.strip.sub(/君\z/, "") }
          discussion_agree_groups = data["衆議院審議時賛成会派"].to_s.split(/、|,|;/).map(&:strip)
          discussion_disagree_groups = data["衆議院審議時反対会派"].to_s.split(/、|,|;/).map(&:strip)
        end

        # 本文情報（要綱リンク）
        if body_href
          body_url = URI.join(base_url, body_href).to_s
          body_html = URI.open(body_url).read.encode("UTF-8", "Shift_JIS")
          body_doc = Nokogiri::HTML.parse(body_html)

          youkou_link = body_doc.css("a").find { |a| a.text.include?("要綱") }
          if youkou_link
            summary_link = URI.join(body_url, youkou_link["href"]).to_s
            summary_doc = Nokogiri::HTML.parse(URI.open(summary_link, "r:Shift_JIS:UTF-8"))
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
        end

        # 保存
        bill = Bill.find_or_initialize_by(title: title)
        bill.kind = kind
        bill.session = session
        bill.bill_number = number
        bill.discussion_status = discussion_status
        bill.summary_link = summary_link
        bill.summary_text = summary_text
        bill.save!

        group_names.each do |g_name|
          next if g_name.blank?
          group = Group.find_or_create_by(name: g_name)
          BillSupport.find_or_create_by(bill: bill, supportable: group, support_type: "propose")
        end

        proposer_names.each do |p_name|
          next if p_name.blank?
          politician = Politician.find_or_create_by(name: p_name)
          BillSupport.find_or_create_by(bill: bill, supportable: politician, support_type: "propose")
        end

        agreeer_names.each do |a_name|
          next if a_name.blank?
          politician = Politician.find_or_create_by(name: a_name)
          BillSupport.find_or_create_by(bill: bill, supportable: politician, support_type: "propose_agree")
        end

        discussion_agree_groups.each do |g_name|
          next if g_name.blank?
          group = Group.find_or_create_by(name: g_name)
          BillSupport.find_or_create_by!(bill: bill,supportable: group,support_type: "agree")
        end

        discussion_disagree_groups.each do |g_name|
          next if g_name.blank?
          group = Group.find_or_create_by(name: g_name)
          BillSupport.find_or_create_by!(bill: bill,supportable: group,support_type: "desagree")
        end

        puts "[#{kind}] Saved: #{session}-#{number}: #{title}"
      end
    end

    puts "Scraping complete."
  end
end
