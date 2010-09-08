class Comment

  include Mongoid::Document

  field :text, :type => String
  # generate data
  field :user_email, :type => String
  field :created_at, :type => Time

  validates_presence_of :text
  index :user_id

  referenced_in :user
  embedded_in :error, :inverse_of => :comments

  validate :user_is_member_of_project

  def update_informations
    self.user_email = self.user.email
    self.created_at ||= Time.now
  end

  def extract_words
    text.split(/[^\w]|[_]/)
  end

  def created_at=(date)
    write_attribute(:created_at, date) unless created_at
  end

  private

  def user_is_member_of_project
    unless self.created_at
      errors.add(:user, 'cant_access') unless self._parent.project.member_include?(user)
    end
  end


end
