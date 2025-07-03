class Bill < ApplicationRecord
  has_many :bill_supports, dependent: :destroy

  def self.ransackable_attributes(auth_object = nil)
    %w[
      title
      kind
      discussion_status
      summary_text
      summary_link
      session
      bill_number
      created_at
      updated_at
    ]
  end
end
