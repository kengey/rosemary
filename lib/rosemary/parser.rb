require 'httparty'
require 'xml/libxml'
class Rosemary::Parser < HTTParty::Parser
  include LibXML::XML::SaxParser::Callbacks

  attr_accessor :context, :description, :lang, :collection

  def parse
    return nil if body.nil? || body.empty?
    if supports_format?
      self.send(format) # This is a hack, cause the xml format would not be recognized ways, but for nodes and relations
    else
      body
    end
  end

  def xml
    @parser = LibXML::XML::SaxParser.string(body)
    @parser.callbacks = self
    @parser.parse
    @collection.empty? ? @context : @collection
  end

  def plain
    body
  end

  def on_start_document   # :nodoc:
    @collection = []
    start_document if respond_to?(:start_document)
  end

  def on_end_document     # :nodoc:
    end_document if respond_to?(:end_document)
  end

  def on_start_element(name, attr_hash)   # :nodoc:
    case name
    when 'node'         then _start_node(attr_hash)
    when 'way'          then _start_way(attr_hash)
    when 'relation'     then _start_relation(attr_hash)
    when 'changeset'    then _start_changeset(attr_hash)
    when 'user'         then _start_user(attr_hash)
    when 'tag'          then _tag(attr_hash)
    when 'nd'           then _nd(attr_hash)
    when 'member'       then _member(attr_hash)
    when 'home'         then _home(attr_hash)
    when 'description'  then @description = true
    when 'lang'         then @lang        = true
    end
  end

  def on_end_element(name)   # :nodoc:
    case name
    when 'description'  then @description = false
    when 'lang'         then @lang        = false
    when 'changeset'    then _end_changeset
    end
  end

  def on_characters(chars)
    if @context.class.name == 'Rosemary::User'
      if @description
        @context.description = chars
      end
      if @lang
        @context.languages << chars
      end
    end
  end

  private

  def _start_node(attr_hash)
    @context = Rosemary::Node.new(attr_hash)
  end

  def _start_way(attr_hash)
    @context = Rosemary::Way.new(attr_hash)
  end

  def _start_relation(attr_hash)
    @context = Rosemary::Relation.new(attr_hash)
  end

  def _start_changeset(attr_hash)
    @context = Rosemary::Changeset.new(attr_hash)
  end

  def _end_changeset
    @collection << @context
  end

  def _start_user(attr_hash)
    @context = Rosemary::User.new(attr_hash)
  end

  def _nd(attr_hash)
    @context << attr_hash['ref']
  end

  def _tag(attr_hash)
    if respond_to?(:tag)
      return unless tag(@context, attr_hash['k'], attr_value['v'])
    end
    @context.tags.merge!(attr_hash['k'] => attr_hash['v'])
  end

  def _member(attr_hash)
    new_member = Rosemary::Member.new(attr_hash['type'], attr_hash['ref'], attr_hash['role'])
    if respond_to?(:member)
      return unless member(@context, new_member)
    end
    @context.members << new_member
  end

  def _home(attr_hash)
    @context.lat = attr_hash['lat']   if attr_hash['lat']
    @context.lon = attr_hash['lon']   if attr_hash['lon']
    @context.lon = attr_hash['zoom']  if attr_hash['zoom']
  end

end