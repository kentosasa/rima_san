# == Schema Information
#
# Table name: candidates
#
#  id          :integer          not null, primary key
#  date        :datetime
#  schedule_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Candidate < ApplicationRecord
  has_many :candidate_user_relations
  has_many :users, :through => :candidate_user_relations

  def attend_users
    ids = self.candidate_user_relations.where(attend: true).pluck(:user_id)
    users = User.where(id: ids)
  end

  def absent_users
    ids = self.candidate_user_relations.where(attend: false).pluck(:user_id)
    users = User.where(id: ids)
  end
end