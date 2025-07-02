class PoliticianGroup < ApplicationRecord
  belongs_to :politician
  belongs_to :group
end
