require_relative '../calendar.rb'


describe Calendar, "#add" do
  it "should start with correct weekday" do
    now = Time.local(2014,11,10,0,0,0)
    calendar = Calendar.new(now)
    calendar.from.to_date.should eq(now.to_date)
  end
  
  it "add normal entry" do
    now = Time.local(2014,11,10,0,0,0)
    calendar = Calendar.new(now)
    calendar.add(now+60*60,now+2*60*60,"Test")
    calendar.get(calendar.from,2).data.should eq("Test")
  end
  
  it "add entry before start" do
    now = Time.local(2014,11,10,0,0,0)
    calendar = Calendar.new(now)
    calendar.add(now-60*60,now+60*60,"Test")
    calendar.get(calendar.from,0).data.should eq("Test")
  end
  it "add entry after end" do
    now = Time.local(2014,11,10,0,0,0)
    calendar = Calendar.new(now)
    calendar.add(now+(7*24-1)*60*60,now+(7*24+1)*60*60,"Test")
    calendar.get(calendar.to-1,46).data.should eq("Test")
  end
end
