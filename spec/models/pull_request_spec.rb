require 'spec_helper'

describe PullRequest do
  let(:user) { create :user }

  it { should belong_to(:user) }
  it { should validate_uniqueness_of(:issue_url).scoped_to(:user_id) }

  describe '#create_from_github' do
    let(:json) { mock_pull_request }

    subject { user.pull_requests.create_from_github(json) }
    its(:title)      { should eq json['payload']['pull_request']['title'] }
    its(:issue_url)  { should eq json['payload']['pull_request']['_links']['html']['href'] }
    its(:created_at) { should eq json['payload']['pull_request']['created_at'] }
    its(:state)      { should eq json['payload']['pull_request']['state'] }
    its(:body)       { should eq json['payload']['pull_request']['body'] }
    its(:merged)     { should eq json['payload']['pull_request']['merged'] }
    its(:repo_name)  { should eq json['repo']['name'] }
    its(:language)   { should eq json['repo']['language'] }

    context 'when the user has authed their twitter account' do
      let(:user) { create :user, :twitter_token => 'foo', :twitter_secret => 'bar' }

      it 'tweets the pull request' do
        twitter = double('twitter')
        twitter.stub(:update)
        User.any_instance.stub(:twitter).and_return(twitter)
        
        user.twitter.should_receive(:update)
          .with(I18n.t 'pull_request.twitter_message', :issue_url => json['payload']['pull_request']['_links']['html']['href'])
        user.pull_requests.create_from_github(json)
      end
    end
  end

  describe '#autogift' do
    context 'when PR body contains "24 pull requests"' do
      it 'creates a gift' do
        pull_request = FactoryGirl.create :pull_request, body: 'happy 24 pull requests!'
        pull_request.gifts.should_not be_empty
      end
    end

    context 'when PR body does not contain "24 pull requests"' do
      it 'does not create a gift' do
        pull_request = FactoryGirl.create :pull_request, body: "...and a merry christmas!"
        pull_request.gifts.should be_empty
      end
    end
  end

  describe "#check_state" do
    let(:pull_request) { create :pull_request }
    before do
      pull_request.stub(:fetch_data).and_return(Hashie::Mash.new mock_issue)
      pull_request.check_state
    end

    subject { pull_request }

    its(:comments_count) { should eq 5        }
    its(:state)          { should eq "closed" }
  end

  context "#scopes" do
    let!(:pull_requests) do
      4.times.map  { |n| create(:pull_request, language: "Haskell",
                                               created_at: DateTime.now+n.minutes) }
    end

    it "by_language" do
      PullRequest.by_language("Haskell").order("created_at asc").should eq pull_requests
    end

    it "latest" do
      PullRequest.latest(3).should eq(pull_requests.reverse.take(3))
    end

  end
end
