namespace :scrape do
  desc "Scrape Sangiin bills (参法・衆法・閣法)"
  task sangiin_hp_bills: :environment do
    require "open-uri"
    require "nokogiri"
    require "pdf-reader"

    # 対象とする国会回次（複数指定可能）
    target_sessions = (211..217).to_a

    target_sessions.each do |session_number|
      puts "========== #{session_number}回次 =========="

      session_url = "https://www.sangiin.go.jp/japanese/joho1/kousei/gian/#{session_number}/gian.htm"
      session_uri = URI.parse(session_url)

      begin
        html = URI.open(session_url).read
        doc = Nokogiri::HTML(html)
      rescue => e
        puts "⚠️ 取得失敗: #{e.message}"
        next
      end

      target_titles = [
        "法律案（内閣提出）一覧",
        "法律案（衆法）一覧",
        "法律案（参法）一覧",   
        "予算一覧",
        "条約一覧",
        "予備費等支出承諾一覧",
        "国会の承認・承諾案件一覧",
        "歳入歳出決算一覧",
        "国有財産増減等計算書一覧",
        "国有財産無償貸付状況一覧",
        "ＮＨＫ決算一覧",
        "決議案一覧",
        "規則案一覧",
        "規程案一覧"
      ]
      
      doc.css("h2.title_text").each do |h2|
        title = h2.text.strip
        next unless target_titles.include?(title)
    
        table = h2.xpath("following-sibling::table").first
        next unless table

        headers = table.css("tr").first.css("th").map(&:text).map(&:strip)
        col_map = {
          session: headers.index("提出回次"),
          number:  headers.index("提出番号"),
          title:   headers.find_index { |h| h.include?("件名") },
        }

        table.css("tr")[1..].each do |tr|
          tds = tr.css("td")
          next if tds.size < col_map.values.compact.max.to_i + 1

          session    = tds[col_map[:session]]&.text&.strip
          number     = tds[col_map[:number]]&.text&.strip

          # 提出法律案PDFリンク
          body_link_href = tds.map { |td|
            link = td.at_css("a")
            link if link&.text&.include?("提出法律案")
          }.compact.first&.[]("href")

          if body_link_href
            body_link = URI.join(session_uri, body_link_href).to_s
            body_pdf_io    = URI.open(body_link)
            body_reader    = PDF::Reader.new(body_pdf_io)
            body_pdf_text  = body_reader.pages.map(&:text).join("\n\n")
          else
            puts "⚠️ 提出法律案リンクを保存できませんでした: #{session}-#{number}"
          end

           #議案要旨PDFリンク
        #   summary_link_href = tds.map { |td|
        #     link = td.at_css("a")
        #     link if link&.text&.include?("議案要旨")
        #   }.compact.first&.[]("href")

        #   summary_link = URI.join(session_uri, summary_link_href).to_s
        #   summary_pdf_io    = URI.open(summary_link)
        #   summary_reader    = PDF::Reader.new(summary_pdf_io)
        #   summary_pdf_text  = summary_reader.pages.map(&:text).join("\n\n")
        # 　bill.sangi_hp_summary_text = summary_pdf_text
        #     bill.save!
        #   else
        #     puts "⚠️ 議案要旨PDFを保存できませんでした: #{session}-#{number}"
        #     next
        #   end  


          # title（文字列とリンク）
          title_td = tds[col_map[:title]]
          title_name = title_td&.text&.strip
          title_link_href = title_td&.at_css("a")&.[]("href")

          #保存
          # bill = Bill.find_or_initialize_by(session: session, number: number, title: title_name)
          normalized_title = title_name.gsub(/[[:space:]\u3000]/, "")
          bill = Bill.where(session: session, number: number).find do |b|
            b.title.gsub(/[[:space:]\u3000]/, "") == normalized_title
          end
          bill ||= Bill.new(session: session, number: number, title: title_name)

          # 件名リンク（詳細ページ）
          title_link = URI.join(session_uri, title_link_href).to_s
          title_html = URI.open(title_link).read.force_encoding("UTF-8").scrub
          title_doc  = Nokogiri::HTML.parse(title_html)
          
          #"種別"を取得
          kind_row = title_doc.at_css("table.list_c tr:has(th:contains('種別'))")
          
          kind = kind_row&.at_css("td")&.text&.strip
          bill.kind = kind
          
          #billを保存
          bill.sangi_hp_body_link = body_link
          # bill.sangi_hp_body_text = body_pdf_text
          if bill.changed?
            begin
                bill.save!
                puts "✅ Saved: #{bill.session}-#{bill.number}-#{bill.title} (kind: #{bill.kind})"
            rescue => e
                puts "❌ Save failed for Bill #{session}-#{number}(kind: #{kind}): #{e.message}"
                puts bill.errors.full_messages
            end
          else
            puts "⏭ Skip: No changes for #{session}-#{number}-#{title_name}(kind: #{kind})"
          end

          #採決結果を取得・保存
          vote_row = title_doc.at_css("table.list_c tr:has(th:contains('採決方法'))")
          if vote_row
            vote_link_href = vote_row.at_css("a")&.[]("href")
            if vote_link_href
              vote_link = URI.join(title_link, vote_link_href).to_s
              vote_doc  = Nokogiri::HTML(URI.open(vote_link, "r:Shift_JIS:UTF-8"))
              vote_doc.css("li.giin").each do |li|

                name = li.at_css(".names")&.text&.strip&.gsub(/[[:space:]　]+/, "")
                next if name.blank?
                normalized_name = name.delete(" ")
                politician = Politician.find_by(normalized_name: normalized_name)
                next if politician.nil?
                support_type =
                  if li.at_css(".pros")&.text&.include?("賛成")
                    "agree"
                  elsif li.at_css(".cons")&.text&.include?("反対")
                    "disagree"
                  else
                    nil
                  end
                next if support_type.nil?
                BillSupport.find_or_create_by(
                  bill: bill,
                  supportable: politician,
                  support_type: support_type
                )
              end
            puts "🗳 Vote info saved for #{session}-#{number}-#{title_name}(kind: #{kind})"
            else
              puts "🔕 採決リンクがありません: #{session}-#{number}-#{title_name}(kind: #{kind})"
            end
          else
            puts "🔕 採決情報がありません: #{session}-#{number}-#{title_name}(kind: #{kind})"
          end
        end
      end
    end
    puts "Sangiin scraping complete."
  end
end
