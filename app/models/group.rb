class Group < ApplicationRecord
  has_many :politician_groups, dependent: :destroy
  has_many :politicians, through: :politician_groups
  has_many :bill_supports, as: :supportable, dependent: :destroy
end
