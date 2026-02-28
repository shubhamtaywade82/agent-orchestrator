class GitManager
  def self.create_branch(task_id, task_description = nil)
    slug = if task_description
             task_description.downcase.gsub(/[^a-z0-0]/, '-').gsub(/-+/, '-').slice(0, 30).strip.gsub(/^-|-$/, '')
           end
    branch_name = slug ? "task-#{task_id}-#{slug}" : "task-#{task_id}"
    `git checkout -b #{branch_name}`
  end

  def self.commit_changes(task_id, task_description)
    `git add .`
    `git commit -m "ares: task-#{task_id} #{task_description}"`
  end
end
