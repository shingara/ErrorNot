require File.dirname(__FILE__) + '/../spec_helper'

describe Comment do


  it { should have_field(:user_id).of_type(BSON::ObjectId) }
  it { should have_field(:user_email).of_type(String) }
  it { should have_field(:text).of_type(String) }
  it { should have_field(:created_at).of_type(Date) }

  def make_comment_with_text(text)
    @user = make_user
    @project = make_project_with_admin(@user)
    @error = Factory(:error, :project => @project)
    @error.comments.build(:user => @user, :text => text)
  end


  describe 'validation' do
    it 'should not valid if no text' do
      make_comment_with_text('')
      @error.should_not be_valid
    end

    it 'should not valid if user is not member of error in root' do
      error = Factory(:error)
      error.comments.build(:user => make_user, :text => 'hello')
      error.should_not be_valid
    end
  end

  describe '#save' do
    it 'should fill user_email with email of user_id' do
      make_comment_with_text('foo')
      @error.save!
      @error.reload.comments.first.user_email.should == @user.email
    end

    it 'should add created_at during creation' do
      make_comment_with_text('foo')
      @error.save!
      @error.comments.first.created_at.should_not be_nil
      create = @error.comments.first.created_at
      @error.comments.first.created_at = 2.days.ago.utc
      @error.save!
      assert_equal create, @error.comments.first.created_at
    end

    it 'should allways valid if comment author is not member of project' do
      make_comment_with_text('foo')
      user = make_user
      @project.members.build(:user => user, :admin => false)
      @project.save!
      @error.reload.comments.build(:user => user, :text => 'bar')
      @error.save!
      @project.remove_member!(:user => user)
      @error.reload.should be_valid
    end
  end
end
