require File.join(File.dirname(__FILE__), '../spec_helper')
require 'pp'

include RubyPicasa

describe User do
  before :all do
    @xml = open_file('user.atom').read
    @class = User
  end

  before do
    @parent = mock('parent')
    @user = User.new(@xml, @parent)
    @user.session = mock('session')
  end

  it 'should have albums' do
    @user.albums.length.should == 1
    @user.albums.first.should be_an_instance_of(Album)
  end
end

describe RecentPhotos do
end

describe Album do
  before :all do
    @xml = open_file('album.atom').read
  end

  before do
    @parent = mock('parent')
    @album = Album.new(@xml, @parent)
    @album.session = mock('session')
  end

  it 'should have 1 entry' do
    @album.entries.length.should == 1
  end

  describe 'photos' do
    it 'should use entries if available' do
      @album.expects(:session).never
      @album.photos.should == @album.entries
    end

    it 'should request photos if needed' do
      @album.entries = []
      new_album = mock('album', :entries => [:photo])
      @album.session.expects(:album).with(@album.id, {}).returns(new_album)
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
  end

end

describe Shared do
  describe 'for Album' do
    before :all do
      @xml = open_file('album.atom').read
    end

    before do
      @parent = mock('parent')
      @album = Album.new(@xml, @parent)
      @album.session = mock('session')
    end

    it 'should have an id' do
      @album.id.should_not be_nil
    end

    it 'should have an author' do
      @album.author.should_not be_nil
      @album.author.name.should == 'Liz'
      @album.author.uri.should == 'http://picasaweb.google.com/liz'
    end

    it 'should get links by name' do
      @album.link('abc').should be_nil
      @album.link('alternate').href.should == 'http://picasaweb.google.com/liz/Lolcats'
    end

    it 'should do nothing for previous and next' do
      @album.previous.should be_nil
      @album.next.should be_nil
    end

    it 'should load' do
      @album.session.expects(:get_url).with(@album.id, {})
      @album.load
    end

    it 'should have 6 links' do
      @album.links.length.should == 6
      @album.links.each do |l|
        l.should be_an_instance_of(Objectify::Atom::Link)
      end
    end

    describe 'session' do
      it 'should return @session' do
        @album.session = :sess
        @album.session.should == :sess
      end

      it 'should get the parent session' do
        @album.session = nil
        @parent.expects(:session).returns(:parent_sess)
        @album.session.should == :parent_sess
      end

      it 'should be nil if no parent' do
        @album.session = nil
        @album.expects(:parent).returns nil
        @album.session.should be_nil
      end
    end

    describe 'first Photo' do
      before do
        @photo = @album.entries.first
        @photo.should be_an_instance_of(Photo)
      end

      it 'should have a content' do
        @photo.content.should be_an_instance_of(PhotoUrl)
      end

      it 'should have 3 thumbnails' do
        @photo.thumbnails.length.should == 3
        @photo.thumbnails.each do |t|
          t.should be_an_instance_of(PhotoUrl)
        end
      end
    end
  end

  describe 'for Search' do
    it 'should request next'
    it 'should request previous'
  end

end
