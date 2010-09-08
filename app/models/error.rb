require 'errornot/callbacks/error_callback'
class Error
  include Mongoid::Document
  include Mongoid::Timestamps

  include Errornot::Callbacks::ErrorCallback

  field :resolved, :type => Boolean, :default => false
  field :session, :type => Hash, :default => {}
  field :raised_at, :type => Time
  field :backtrace, :type => Array, :default => []
  field :request, :type => Hash, :default => {}
  field :environment, :type => Hash, :default => {}
  field :data, :type => Hash, :default => {}
  field :unresolved_at, :type => Time
  field :resolved_at, :type => Time
  field :resolveds_at, :type => Array, :default => []

  field :message, :type => String

  # Denormalisation
  field :_keywords, :type => Array, :default => []
  field :last_raised_at, :type => Time


  index :resolved
  index :_keyords
  index :project_id
  index :raised_at

  validates_presence_of :project_id
  validates_presence_of :message
  validates_presence_of :raised_at
  validates_associated :comments

  referenced_in :project
  embeds_many :comments

  references_many :same_errors, :class_name => 'ErrorEmbedded'


  # To keep track of some metrics:
  field :nb_comments, :type => Integer, :default => 0
  field :count, :type => Integer, :default => 1 # nb of same errors

  validates_presence_of :nb_comments
  validates_presence_of :count

  ## Callback
  before_validation :update_last_raised_at

  before_save :update_comments
  before_save :update_count

  after_create :send_notify

  after_save :update_nb_errors_in_project
  after_save :update_keywords


  def url
    request['url']
  end

  def params
    request['params']
  end

  def resolved!
    self.resolved = true
    save!
  end

  def same_errors_most_recent(page, per_page=10)
    same_errors.paginate(:order => 'raised_at DESC',
                         :per_page => per_page,
                         :page => page)
  end


  ##
  # code to update keywords
  # Not call in direct
  def update_keywords_task
    words = (self.message.split(/[^\w]|[_]/) | self.comments.map(&:extract_words)).flatten
    self._keywords = words.delete_if(&:empty?).uniq
    # We made update direct to avoid some all callback recall
    Error.collection.update({:_id => self.id}, {'$set' => {:_keywords => self._keywords}})
  end

  def update_comments
    self.nb_comments = comments.length
    comments.each do |comment|
      comment.update_informations
    end
  end

  def update_count
    self.count = 1 + same_errors.length
  end

  ##
  # Call by send_notify
  def send_notify_task
    Project.find(project_id).members.each do |member|
      if member.notify_by_email?
        UserMailer.error_notify(member.email, self).deliver
      end
    end
  end

  def resolved=(resolution)
    old_resolution = read_attribute(:resolved)
    # check if string and replace it by a bool. Controller send String, not bool
    resolution = resolution == 'true' if resolution.kind_of?(String)
    if old_resolution && !resolution
      self.unresolved_at = Time.now.utc
    end

    if !old_resolution && resolution
      self.resolved_at = Time.now
      self.resolveds_at << self.resolved_at.utc
    end
    write_attribute(:resolved, resolution)
  end

  private

  def update_last_raised_at
    self.last_raised_at ||= self.raised_at
    self.unresolved_at ||= self.raised_at
  end

end
