Errornot::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  resources :project do
    member do
      put :add_member
      delete :remove_member
      get :leave
      delete :leave
      put :admins
      delete :admins
      put :reset_apikey
    end
    resources :errors, :except => [:new, :create, :update] do
      member do
        post :comment
        get :backtrace
        get :session_info
        get :data
        get :similar_error
        get :request_info
      end
      resources :same_errors, :only => [:show] do
        member do
          get :backtrace
          get :session_info
          get :data
          get :similar_error
          get :request_info
        end
      end
    end
  end


  resources :errors, :only => [:create, :update]

  devise_for :users
  resources :user do
    collection do
      put :update_notify
    end
  end
  root :to => 'projects#index'
end
