class Member
  include Mongoid::Document

  field :admin, :type => Boolean
  field :notify_by_email, :type => Boolean, :default => true
  field :notify_removal_by_email, :type => Boolean, :default => true
  field :notify_by_digest, :type => Boolean, :default => false
  field :digest_send_at, :type => Time
  field :email, :type => String
  field :status, :type => Integer, :default => 0

  AWAITING = 0
  UNVALIDATE = 1
  VALIDATE = 2

  index :user_id
  referenced_in :user
  embedded_in :project, :inverse_of => :members

  validates_presence_of :user_id, :if => Proc.new { email.blank? }


  before_save :update_data
  before_save :need_admin_members

  def update_data
    unless user_id
      self.status = AWAITING
    else
      if user.confirmed?
        self.status = VALIDATE
      else
        self.status = UNVALIDATE
      end
      self.email = user.email
    end
  end

  ##
  # Update digest_send_at if needed
  #
  def notify_by_digest=(notify)
    write_attribute(:notify_by_digest, notify)
    self.digest_send_at = Time.now.utc if notify && !self.digest_send_at
    self.digest_send_at = nil unless notify
  end

  ##
  # Send a digest about all error not already send by digest
  # from project where this member is
  def send_digest
    return unless notify_by_digest
    errors = self._root_document.error_reports.not_send_by_digest_since(self.digest_send_at)
    UserMailer.error_digest_notify(self.email, errors).deliver unless errors.empty?
    self.digest_send_at = Time.now.utc
    self.save
    true
  end

  def need_admin_members
    errors.add(:admin, 'last admin of this project') unless parent.members.any?{ |m| m.admin }
  end

end
