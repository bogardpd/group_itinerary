class UsersController < ApplicationController
  before_action :logged_in_user, only: [:index, :show, :edit, :update, :destroy]
  before_action :correct_user, only: [:show, :edit, :update]
  before_action :admin_user, only: [:index, :destroy]
  
  def index
    @users = User.all
  end
  
  def show
    @user = User.find(params[:id])
    @events_table = @user.events_table
  end
  
  def new
    @user = User.new
  end
  
  def create
    flash[:danger] = "Not currently accepting new users"
    redirect_to root_url
    # @user = User.new(user_params)
    # if @user.save
    #   log_in @user
    #   flash[:success] = "Welcome to Shared Itinerary!"
    #   redirect_to @user
    # else
    #   render 'new'
    # end
  end
  
  def edit
  end
  
  def update
    if @user.update_attributes(user_params)
      flash[:success] = "Profile updated"
      redirect_to @user
    else
      render 'edit'
    end
  end
  
  def destroy
    User.find(params[:id]).destroy
    flash[:success] = "User deleted"
    redirect_to users_url
  end
  
  private
    
    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
    
    # Before filters
    
    # Confirms the correct user.
    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_url) unless current_user?(@user)
    end
    
    
  
end
