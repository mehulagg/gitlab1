# frozen_string_literal: true

scope '-' do
  resource :profile, only: [] do
    scope module: :profiles do
      resource :slack, only: [:edit] do
        member do
          get :slack_link
        end
      end

      resources :usage_quotas, only: [:index]
      resources :billings, only: [:index]
    end
  end
end

Gitlab::Routing.redirect_legacy_paths(self, :profile)
