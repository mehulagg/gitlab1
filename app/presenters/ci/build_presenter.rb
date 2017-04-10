module Ci
  class BuildPresenter < Gitlab::View::Presenter::Delegated
    presents :build

    def erased_by_user?
      # Build can be erased through API, therefore it does not have
      # `erased_by` user assigned in that case.
      erased? && erased_by
    end

    def erased_by_name
      erased_by.name if erased_by_user?
    end

    def status_title
      if auto_canceled?
        "Job is redundant and is auto-canceled by Pipeline ##{auto_canceled_by_id}"
      end
    end
  end
end
