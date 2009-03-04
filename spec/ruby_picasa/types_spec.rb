require File.join(File.dirname(__FILE__), '../spec_helper')

include RubyPicasa

describe 'a RubyPicasa document', :shared => true do
  it 'should have an id' do
    @object.id.should_not be_nil
  end

  it 'should have an author' do
    unless @no_author
      @object.author.should_not be_nil
      @object.author.name.should == 'Liz'
      @object.author.uri.should == 'http://picasaweb.google.com/liz'
    end
  end

  it 'should get links by name' do
    @object.link('abc').should be_nil
    @object.link('self').href.should_not be_nil
  end

  it 'should do nothing for previous and next' do
    @object.previous.should be_nil if @object.link('previous').nil?
    @object.next.should be_nil if @object.link('next').nil?
  end

  it 'should get the feed' do
    @object.session.expects(:get_url).with(@object.id.gsub(/entry/, 'feed').gsub(/default/, 'liz'), {})
    @object.feed
  end

  it 'should have links' do
    @object.links.should_not be_empty
    @object.links.each do |l|
      l.should be_an_instance_of(Objectify::Atom::Link)
    end
  end

  describe 'session' do
    it 'should return @session' do
      @object.session = :sess
      @object.session.should == :sess
    end

    it 'should get the parent session' do
      @object.session = nil
      @parent.expects(:session).returns(:parent_sess)
      @object.session.should == :parent_sess
    end

    it 'should be nil if no parent' do
      @object.session = nil
      @object.expects(:parent).returns nil
      @object.session.should be_nil
    end
  end
end


describe User do
  it_should_behave_like 'a RubyPicasa document'

  before :all do
    @xml = open_file('user.atom').read
  end

  before do
    @parent = mock('parent')
    @object = @user = User.new(@xml, @parent)
    @user.session = mock('session')
  end

  it 'should have albums' do
    @user.albums.length.should == 1
    @user.albums.first.should be_an_instance_of(Album)
  end
end

describe RecentPhotos do
  it_should_behave_like 'a RubyPicasa document'

  before :all do
    @xml = open_file('recent.atom').read
  end

  before do
    @parent = mock('parent')
    @object = @album = RecentPhotos.new(@xml, @parent)
    @album.session = mock('session')
  end

  it 'should have 1 photo' do
    @album.photos.length.should == 1
    @album.photos.first.should be_an_instance_of(Photo)
  end

  it 'should request next' do
    @album.session.expects(:get_url).with('http://picasaweb.google.com/data/feed/api/user/liz?start-index=2&max-results=1&kind=photo').returns(:result)
    @album.next.should == :result
  end

  it 'should not request previous on first page' do
    @album.session.expects(:get_url).never
    @album.previous.should be_nil
  end
end

describe Album do
  it_should_behave_like 'a RubyPicasa document'

  before :all do
    @xml = open_file('album.atom').read
  end

  before do
    @parent = mock('parent')
    @object = @album = Album.new(@xml, @parent)
    @album.session = mock('session')
  end

  it 'should have 1 entry' do
    @album.entries.length.should == 1
  end

  it 'should get links by name' do
    @album.link('abc').should be_nil
    @album.link('alternate').href.should == 'http://picasaweb.google.com/liz/Lolcats'
  end

  describe 'photos' do
    it 'should use entries if available' do
      @album.expects(:session).never
      @album.photos.should == @album.entries
    end

    it 'should request photos if needed' do
      @album.entries = []
      new_album = mock('album', :entries => [:photo])
      @album.session.expects(:get_url).with(@album.link(/feed/).href, {}).returns(new_album)
      @album.photos.should == [:photo]
    end
  end

  it 'should be public' do
    @album.public?.should be_true
  end

  it 'should not be private' do
    @album.private?.should be_false
  end

  describe 'first Photo' do
    before do
      @photo = @album.entries.first
      @photo.should be_an_instance_of(Photo)
    end

    it 'should have a parent' do
      @photo.parent.should == @album
    end

    it 'should not have an author' do
      @photo.author.should be_nil
    end

    it 'should have a content' do
      @photo.content.should be_an_instance_of(PhotoUrl)
    end

    it 'should have 3 thumbnails' do
      @photo.thumbnails.length.should == 3
      @photo.thumbnails.each do |t|
        t.should be_an_instance_of(ThumbnailUrl)
      end
    end

    it 'should have a default url' do
      @photo.url.should == 'http://lh5.ggpht.com/liz/SKXR5BoXabI/AAAAAAAAAzs/tJQefyM4mFw/invisible_bike.jpg'
    end

    it 'should have thumbnail urls' do
      @photo.url('72').should == 'http://lh5.ggpht.com/liz/SKXR5BoXabI/AAAAAAAAAzs/tJQefyM4mFw/s72/invisible_bike.jpg'
    end

    it 'should have thumbnail info' do
      @photo.thumbnail('72').width.should == 72
    end
  end
end

describe Search do
  it_should_behave_like 'a RubyPicasa document'

  before :all do
    @xml = open_file('search.atom').read
  end

  before do
    @no_author = true
    @parent = mock('parent')
    @object = @search = Search.new(@xml, @parent)
    @search.session = mock('session')
  end

  it 'should have 1 entry' do
    @search.entries.length.should == 1
    @search.entries.first.should be_an_instance_of(Photo)
  end

  it 'should request next' do
    @search.session.expects(:get_url).with('http://picasaweb.google.com/data/feed/api/all?q=puppy&start-index=3&max-results=1').returns(:result)
    @search.next.should == :result
  end

  it 'should request previous' do
    @search.session.expects(:get_url).with('http://picasaweb.google.com/data/feed/api/all?q=puppy&start-index=1&max-results=1').returns(:result)
    @search.previous.should == :result
  end
end

