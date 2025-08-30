class Bill < ApplicationRecord
  has_many :bill_supports, dependent: :destroy
  validates :session, :title, :kind, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[title]
  end

  def self.ransackable_associations(auth_object = nil)
    ["bill_supports"]
  end
end
