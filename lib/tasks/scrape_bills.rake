namespace :scrape do
  desc "Scrape bills from Shugiin"
  task bills: :environment do
    require "open-uri"
    require "nokogiri"

    base_url = "https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/menu.htm"
    index_html = URI.open(base_url).read
    index_doc = Nokogiri::HTML.parse(index_html)

    index_doc.css("table tr").each do |tr|
      tds = tr.css("td")
      next if tds.size < 6

      session = tds[0].text.strip
      number = tds[1].text.strip
      title = tds[2].text.strip
      discussion_status = tds[3].text.strip

      progress_href = tds[4].at_css("a")&.[]("href")
      next unless progress_href

      progress_url = URI.join(base_url, progress_href).to_s
      progress_html = URI.open(progress_url, "r:Shift_JIS:UTF-8").read
      progress_doc = Nokogiri::HTML.parse(progress_html)

      kind = nil
      group_names = []
      proposer_names = []
      agreeer_names = []

      # ここから progress_doc の tr loop
      rows = progress_doc.css("tr")
      # Row番号で取得
      rows.each_with_index do |row, i|
        tds = row.css("td")
        next unless tds.size == 2

        content = tds[1].text.strip

        case i
        when 1
          kind = content
        when 4
          # 議案件名はtitleで既に取っているのでスキップでもOK
        when 6
          group_names = content.split(/、|,|\s+/)
        when 23
          proposer_names = content.split(/、|,|;/).map(&:strip)
        when 24
          agreeer_names = content.split(/、|,|;/).map(&:strip)
        end
      end
      # progress_doc の tr loop ここで閉じる

      # 本文情報URL
      body_href = tds[5]&.at_css("a")&.[]("href")
      summary_text = nil
      summary_link = nil
      if body_href
        body_url = URI.join(base_url, body_href).to_s
        body_html = URI.open(body_url).read.encode("UTF-8", "Shift_JIS")
        body_doc = Nokogiri::HTML.parse(body_html)

        youkou_link = body_doc.css("a").find { |a| a.text.include?("要綱") }
        if youkou_link
          summary_link = URI.join(body_url, youkou_link["href"]).to_s
          summary_text = Nokogiri::HTML(URI.open(summary_link)).text.strip
        end
      end

      bill = Bill.find_or_initialize_by(title: title)
      bill.kind = kind
      bill.discussion_status = discussion_status
      bill.session = session
      bill.bill_number = number
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

      puts "Groups: #{group_names.inspect}"
      puts "Proposers: #{proposer_names.inspect}"
      puts "Agreeers: #{agreeer_names.inspect}"
    end # index_doc.each
  end # task
end # namespace
