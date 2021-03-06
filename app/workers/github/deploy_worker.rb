module Github
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployDeployTargetWorker')

      job = Genova::Sidekiq::Queue.find(id)

      deploy_target = deploy_target(job[:account], job[:repository], job[:branch])
      return if deploy_target.nil?

      deploy_job = DeployJob.create(
        id: id,
        type: DeployJob.type.find_value(:service),
        status: DeployJob.status.find_value(:in_progress),
        mode: DeployJob.mode.find_value(:auto),
        account: job[:account],
        repository: job[:repository],
        branch: job[:branch],
        cluster: deploy_target[:cluster],
        service: deploy_target[:service]
      )

      bot = Genova::Slack::Bot.new
      bot.post_detect_auto_deploy(deploy_job)
      bot.post_started_deploy(deploy_job, jid)

      client = Genova::Client.new(
        deploy_job,
        lock_timeout: Settings.github.deploy_lock_timeout
      )
      client.run

      bot.post_finished_deploy(deploy_job)
    end

    private

    def deploy_target(account, repository, branch)
      code_manager = Genova::CodeManager::Git.new(account, repository, branch: branch)
      auto_deploy_config = code_manager.load_deploy_config[:auto_deploy]

      return nil if auto_deploy_config.nil?

      deploy_target = auto_deploy_config.find { |k, _v| k[:branch] == branch }

      return nil if deploy_target.nil?

      {
        cluster: deploy_target[:cluster],
        service: deploy_target[:service]
      }
    end
  end
end
