class ErrorEmbedded
  include Mongoid::Document

  field :session, :type => Hash
  field :raised_at, :type => Time
  field :request, :type => Hash
  field :environment, :type => Hash
  field :data, :type => Hash

  validates_presence_of :raised_at

  referenced_in :root_error, :class_name => 'Error', :inverse_of => :same_error, :foreign_key => 'error_id'

  index :error_id

  delegate :last_raised_at, :to => :root_error
  delegate :same_errors, :to => :root_error
  delegate :project, :to => :root_error
  delegate :comments, :to => :root_error
  delegate :resolved, :to => :root_error
  delegate :message, :to => :root_error
  delegate :backtrace, :to => :root_error
  delegate :count, :to => :root_error

  after_create :reactive_error

  after_save :update_last_raised_at
  after_save :update_error_count

  def url
    request['url']
  end

  def params
    request['params']
  end

  private

  def reactive_error
    if root_error.resolved
      root_error.resolved = false
      root_error.send_notify
      root_error.save!
    end
  end

  ##
  # Call by update_last_raised_at
  def update_last_raised_at
    if root_error.last_raised_at.utc < raised_at.utc
      Error.collection.update({:_id => root_error.id}, {"$set" => {:last_raised_at => raised_at.utc}})
    end
  end

  def update_error_count
    Error.collection.update({:_id => root_error.id}, {'$set' => {:count => root_error.reload.update_count}}, {:safe => true})
  end

end
