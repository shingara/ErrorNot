class Error
  include MongoMapper::Document
  include Callbacks::ErrorCallback

  key :resolved, Boolean, :index => true
  key :session, Hash
  key :raised_at, Time, :required => true
  key :backtrace, Array
  key :request, Hash
  key :environment, Hash
  key :data, Hash
  key :unresolved_at, Time
  key :resolved_at, Time
  key :resolveds_at, Array

  key :message, String, :required => true

  # Denormalisation
  key :_keywords, Array, :index => true, :default => []
  key :last_raised_at, Time

  key :project_id, ObjectId, :required => true, :index => true
  belongs_to :project

  has_many :comments
  include_errors_from :comments

  has_many :same_errors, :class_name => 'ErrorEmbedded'
  include_errors_from :same_errors

  # To keep track of some metrics:
  key :nb_comments, Integer, :required => true, :default => 0
  key :count, Integer, :required => true, :default => 1 # nb of same errors

  ## Callback
  before_validation :update_last_raised_at

  before_save :update_comments
  before_save :update_count

  after_create :send_notify

  after_save :update_nb_errors_in_project
  after_save :update_keywords

  timestamps!

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
        UserMailer.deliver_error_notify(member.email, self)
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
