require File.dirname(__FILE__) + '/../spec_helper'

describe ErrorEmbedded do

  ['session', 'raised_at', 'request', 'environment',
   'data'].each do |field|
    it "should have field #{field}" do
      assert ErrorEmbedded.keys.keys.include?(field)
    end
  end

  describe '#validation' do
    it 'should have a raise_at require' do
      project = make_project_with_admin
      error = Factory(:error, :project => project)
      error_2 = Factory.build(:error, :project => project,
                              :message => error.message,
                              :backtrace => error.backtrace)
      error_embedded = project.error_with_message_and_backtrace(error_2.message,
                                                                error_2.backtrace)
      error_embedded.update_attributes(:raised_at => nil)
      error_embedded._root_document.should_not be_valid
    end
  end

  it 'should send notify by email if reactivate resolved in error root if resolved mark like true' do
    user = make_user
    project = make_project_with_admin(user)
    error = Factory(:error,
                    :raised_at => 3.minutes.ago.utc,
                    :project => project,
                    :resolved => true)
    error_2 = Factory.build(:error,
                            :project => project,
                            :raised_at => 1.minute.ago.utc,
                            :message => error.message,
                            :backtrace => error.backtrace)
    error_embedded = project.error_with_message_and_backtrace(error_2.message,
                                                              error_2.backtrace)
    UserMailer.expects(:deliver_error_notify).with{ |email, error|
      email == user.email && error.kind_of?(Error)
    }
    error_embedded.update_attributes(error_2.attributes)
  end

  it 'should update count of error when new error_embedded' do
    project = make_project_with_admin
    error = Factory(:error, :project => project)
    error.count.should == 1
    error_embedded = project.error_with_message_and_backtrace(error.message,
                                                              error.backtrace)
    error_embedded.raised_at = Time.now.utc
    error_embedded.save!
    Error.find(error.id).count.should == 2
  end

end
