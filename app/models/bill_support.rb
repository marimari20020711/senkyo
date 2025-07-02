class BillSupport < ApplicationRecord
  belongs_to :bill
  belongs_to :supportable, polymorphic: true
end
