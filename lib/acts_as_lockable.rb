require 'activerecord'

module Thincloud
  module Acts
    
    # === Simple delete and update locking
    #
    # @obj.lock!(:desc => "Because I said so")
    # @obj.unlock!
    # @obj.locked?
    #
    # === Lock record per user
    # 
    # First make the current_user available in ActiveRecord 
    # and put this in your application_controller.rb or a initializer:
    #
    # class ActiveRecord::Base
    #   cattr_accessor :current_user
    # end
    # 
    # ActiveRecord::Base.current_user = current_user # <= Should be an UserObject, id as primary key
    #
    #
    # Lock the record for the current user and next 5 minutes
    # 
    # @obj.lock!(:desc => "No more beer!", :user_id => 123, :timeout => 5.minutes.from_now)
    #
    # In the next 5 minutes nobody expect user with id 123 can destroy, update or lock the record.
    # You can also lock the record forever:
    #
    # @obj.lock!(:desc => "No more smoking - forever!", :user_id => 123)
    #
    # So nobody except user 123 can destroy, update or lock this record forever 
    # until user 123 unlocks it:
    #
    # @obj.unlock!
    
    module Lockable
      
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_lockable(options = {})
          has_many :locks, :as => :locked
          before_destroy :prevent_destroy_lock_pick
          before_update :prevent_update_lock_pick
          include InstanceMethods
        end

        def lockable?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        
        def lock!(options={})
          
          raise LockedLockError if self.locked? and !options[:user_id].nil?
          
          self.locks.destroy_all
          
          self.locks.create(:desc => options[:desc], 
                            :timeout => options[:timeout],
                            :user_id => options[:user_id])
        end
        
        def unlock!
          raise LockedUnlockError if self.locked? and !self.locks.first.user_id.nil?
          self.locks.destroy_all
        end
        
        def locked?
          if self.locks.size > 0 and self.locks.first.user_id.nil?
            true
          elsif self.locks.size > 0 and (self.locks.first.timeout.nil? or 
                                         self.locks.first.timeout > Time.now)
            self.locks.first.user_id != self.current_user.id
          end
        end
        
        private 
        
        def prevent_destroy_lock_pick
            raise LockedDestroyError if self.locked?
        end
        
        def prevent_update_lock_pick
          
          if self.locks.first.user_id.nil? or self.locks.first.user_id != self.current_user.id
            raise LockedUpdateError if self.locked?
          end
          
        end
      end      
    end
  end
end

class LockedDestroyError < StandardError; end
class LockedUpdateError < StandardError; end
class LockedLockError < StandardError; end
class LockedUnlockError < StandardError; end

  
