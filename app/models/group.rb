class Group < ApplicationRecord
  has_many :politician_groups, dependent: :destroy
  has_many :politicians, through: :politician_groups
  has_many :bill_supports, as: :supportable, dependent: :destroy
  
  def self.ransackable_attributes(auth_object = nil)
    %w[name]
  end

  def self.ransackable_associations(auth_object = nil)
    ["bill_supports"]
  end
end