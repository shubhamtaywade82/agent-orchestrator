class GitManager
  def self.create_branch(task_id)
    `git checkout -b task-#{task_id}`
  end

  def self.commit_changes(task_id, task_description)
    `git add .`
    `git commit -m "ares: task-#{task_id} #{task_description}"`
  end
end
