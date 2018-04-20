require 'csv'

class CBETA::Canon
  def initialize
    fn = File.join(File.dirname(__FILE__), '../data/canons.csv')
    text = File.read(fn)
    @canons = {}
    CSV.parse(text, :headers => true) do |row|
      id = row['id']
      @canons[id] = row
    end
  end
  
  def get_canon_attr(canon_id, attr_name)
    @canons[canon_id][attr_name]
  end
end