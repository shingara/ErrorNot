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
  key :error_id, ObjectId

  key :message, String, :required => true

  # Denormalisation
  key :_keywords, Array, :index => true
  key :last_raised_at, Time

  key :project_id, ObjectId, :required => true, :index => true
  belongs_to :project

  has_many :comments
  include_errors_from :comments

  has_many :same_errors, :class_name => 'Error', :foreign_key => 'error_id'
  belongs_to :root_error, :class_name => 'Error', :foreign_key => 'error_id'

  # To keep track of some metrics:
  key :nb_comments, Integer, :required => true, :default => 0
  key :count, Integer, :required => true, :default => 1 # nb of same errors

  ## Callback
  before_create :define_unresolved_at

  before_validation :fill_error

  before_save :update_comments
  before_save :update_count
  before_save :reactive_if_new_error

  after_create :send_notify, :unless => :error_id

  after_save :update_nb_errors_in_project
  after_save :update_keywords
  after_save :update_last_raised_at


  after_update :resend_notify


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
  # Call by update_last_raised_at
  def update_last_raised_at_task
    unless error_id
      Error.collection.update({:_id => _id}, {'$set' => {:last_raised_at => raised_at.utc}})
    else
      last_raised_at = Error.first(:error_id => error_id, :order => 'raised_at DESC').raised_at
      Error.collection.update({:_id => error_id}, {'$set' => {:last_raised_at => last_raised_at.utc}})
    end
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
      self.unresolved_at = Time.now
    end

    if !old_resolution && resolution
      self.resolved_at = Time.now
      self.resolveds_at << self.resolved_at.utc
    end
    write_attribute(:resolved, resolution)
  end

  private

  def resend_notify
    if error_id
      root_error.resend_notify
    else
      send_notify if !resolved? && same_errors.length < 1 && new_same_error?
    end
  end

  ##
  # Mark error like un_resolved if a new error is add
  # An new error is arrived if embedded has no id ( little hack )
  # Resend a notification if was marked as resolved and re-raised.
  #
  def reactive_if_new_error
    if error_id
      root_error.reactive_if_new_error
    else
      if self.resolved && new_same_error?
        self.resolved = false
        send_notify if same_errors.length > 0
      end
    end
  end

  # Check if new error embedded
  def new_same_error?
    same_errors.any?{|error| error.new? }
  end

  def define_unresolved_at
    self.unresolved_at = Time.now unless self.unresolved_at
  end

  def fill_error
    if error_id
      self.message = root_error.message
      self.project_id = root_error.project_id
    end
  end

end
