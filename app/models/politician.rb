class Politician < ApplicationRecord
  before_save :set_normalized_name

  has_many :politician_groups, dependent: :destroy
  has_many :groups, through: :politician_groups
  has_many :bill_supports, as: :supportable, dependent: :destroy
  has_many :speeches, dependent: :destroy

  def self.ransackable_attributes(auth_object = nil)
    %w[name]
  end

  def self.ransackable_associations(auth_object = nil)
    ["bill_supports"]
  end

  private

  def set_normalized_name
    self.normalized_name = name.to_s.delete(" ")
  end
end