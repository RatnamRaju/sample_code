# there are three processes here
# new -> create:: buy a new plan now (sets up a plan and cc info) create charges cc
# confirm -> upgrade:: upgrade or downgrade (sets up a plan without changing cc info) upgrade charges cc
# edit -> update:: change credit card infos (NOTE: params[:id] is the payment_method id) update does not charge cc (unless was delinquent)
class TermsNotAccepted < RuntimeError; end
class PlansController < ApplicationController
  #layout 'internal'

  before_filter :login_required, :except => [ :index, :postback ]

  #before_filter :ensure_secure

  def show
    @plan = current_user.plan
  end
  
  def new
    @plan = Plan.new(:price => 0)
    @plan_templates = PlanTemplate.products(current_user)
    @plan_template = PlanTemplate.find_by_name params[:plan]
    @plan_template = Plan.find(params[:plan]) if @plan_template.nil? and params[:plan].present?
    # this will be the default if everything else fails
    @plan_template = PlanTemplate.find_by_handle 'subs500' if @plan_template.nil?
    @account = current_user
 #render :text => 'hai'and return
    render :action => 'edit'
  end
  
  def create
    Plan.transaction do
      @account = current_user
      first = @account.plans.empty?
      @plan_template = PlanTemplate.find(params[:plan])
      @plan_templates = PlanTemplate::products(current_user)

      @plan = @account.plans.build :plan_template => @plan_template

      @plan.coupon_code = params[:coupon_code]
      @plan.credit_card = params[:credit_card]
        
      add_keywords(params)
    
      if @plan.save then
        @account.update_attribute(:zip, params[:credit_card][:zip])
        @account.update_attribute(:plan, @plan)
        @custom_plan.destroy if @custom_plan.present?

        flash[:notice] = I18n.t('plan.create_success')
        flash[:purchase] = "true"
        add_query = {}
        if first
          @account.salesforce_update_background
          flash[:first_plan] = "true"
          add_query = {:first => "subscription", :s => current_user.source}
        end
        $gibbon.list_unsubscribe(:id => GLOBALS['mailchimp_lists']['trial'], :email_address => @account.email, :send_goodbye => false, :send_notify => false)
        $gibbon.list_unsubscribe(:id => GLOBALS['mailchimp_lists']['follow_up'], :email_address => @account.email, :send_goodbye => false, :send_notify => false)
        $gibbon.list_unsubscribe(:id => GLOBALS['mailchimp_lists']['monthly_promotion'], :email_address => @account.email, :send_goodbye => false, :send_notify => false)
        redirect_to(account_path(add_query)) and return
      else
        if @plan.errors.present?
          flash[:error] = (@plan.errors.full_messages + [flash[:error]]).join(' ');
        else
          flash[:error] = I18n.t 'plan.upgrade_error'
        end
        render :action => 'edit'
      end
    end
  end
  
  def confirm
    @plan = current_user.plan
    @plan_template = PlanTemplate.find_by_name params[:plan]
    
    respond_to do |format|
      format.html
      format.partial { render :action => 'confirm.html.erb', :layout => false }
    end
  end
  
  # change credit card info
  def edit
    @plan = current_user.plan
    if @plan.nil?
      redirect_to new_plan_path
      return
    end

    if current_user.canceled?
      @plan_templates = PlanTemplate.products
    else
      @plan_templates = PlanTemplate.products
    end
    @plan_template = @plan.plan_template if @plan
    @plan_template = @plan if @plan_template.nil? and @plan.present?
    @account = current_user

  end

  def update # change the credit card infos
    @account = current_user
    was_canceled = current_user.canceled?
    @plan = @account.plan
    @plan_template = PlanTemplate.find_by_id params[:plan]
    @plan_template = Plan.find(params[:plan]) if @plan_template.nil? and params[:plan].present?
    @plan_template = @plan.plan_template if @plan_template.nil?
    @plan.credit_card = params[:credit_card] if params[:credit_card].present?
    @plan_templates = PlanTemplate.products(current_user)

    if params[:plan] and @plan_template.price < (@plan.price.cents/100) and !current_user.canceled? then
      flash[:error] = "To downgrade, please contact Tatango"
      render :action => 'edit'
    elsif @plan.save then
      if params[:credit_card]
        @account.update_attribute(:zip, params[:credit_card][:zip])
      end

      if was_canceled
        flash[:notice] = I18n.t(:'plan.after_undo_cancel')
      else
        flash[:notice] = I18n.t(:'plan.after_cc_change')
      end

      add_keywords(params)
      
      if @plan_template != @plan.plan_template
        if @plan.upgrade(@plan_template.handle)
          flash[:notice] = I18n.t('plan.upgrade_success')
          flash[:purchase] = @plan.price.to_s
        else
          if @plan.errors.present?
            flash[:error] = (@plan.errors.full_messages + flash[:error].to_a).join(' ');
          else
            flash[:error] = I18n.t 'plan.upgrade_error'
          end
        end
      end
      redirect_to(account_path) and return

    else
      if @plan.errors.nil?
        flash.now[:error] = I18n.t :'plan.credit_card_error'
      else
        @plan.errors.each{|attr,msg| flash.now[:error] = msg }
      end
      flash.now[:cc] = 'update'
      
      render :action => 'edit'
    end
  end


  def upgrade # or downgrade
    handle = PlanTemplate.find_by_name(params[:plan]).try(:handle)
    
    if current_user.plan.upgrade(handle)
      current_user.plan.subscription(true) # force reload
      #Mailer::Pimped.deliver_plan_change current_user.plan
      flash[:notice] = I18n.t 'plan.upgrade_success'
    else
      if @plan.errors.present?
        flash[:error] = (@plan.errors.full_messages + flash[:error].to_a).join(' ');
      else
        flash[:error] = I18n.t 'plan.upgrade_error'
      end
    end
    redirect_to(plans_path) and return
  end


  private


  def add_keywords(params)
    if (params[:subs] and params[:subs] != "0") or !@account.created_lists.empty?
      for i in 1..(params[:subscription_keywords].to_i - @account.created_lists.size)
        list = List.new
        list.created_by = @account.id
        list.save
      end
    end

    if (params[:autores] and params[:autores] != "0") or !@account.created_autoresponders.empty?
      for i in 1..(params[:autoresponder_keywords].to_i - @account.created_autoresponders.size)
        autoresponder = Autoresponder.new
        autoresponder.created_by = @account.id
        autoresponder.save
      end
    end
  end

end