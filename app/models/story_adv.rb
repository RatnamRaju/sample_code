class StoryAdv < ActiveRecord::Base
  
     belongs_to :story, :class_name => "Story", :foreign_key => "story_id"
     belongs_to :top_adv, :class_name => "Advertisement", :foreign_key => "topadv_id", :conditions => ["status like ?",1]
     belongs_to :bottom_adv, :class_name => "Advertisement", :foreign_key => "bottomadv_id", :conditions => ["status like ?",1]
     belongs_to :header_adv, :class_name => "Advertisement", :foreign_key => "headeradv_id", :conditions => ["status like ?",1]
     belongs_to :story_top_adv, :class_name => "AdvList", :foreign_key => "headeradv_id"
     belongs_to :story_left_top_adv, :class_name => "AdvList", :foreign_key => "topadv_id"
     belongs_to :story_left_bottom_adv, :class_name => "AdvList", :foreign_key => "bottomadv_id"
     belongs_to :story_right_adv, :class_name => "AdvList", :foreign_key => "rightadv_id"
end
