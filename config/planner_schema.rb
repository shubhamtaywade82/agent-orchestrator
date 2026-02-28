PLANNER_SCHEMA = {
  'type' => 'object',
  'required' => %w[task_type risk_level confidence slices],
  'additionalProperties' => false,
  'properties' => {
    'task_type' => {
      'type' => 'string',
      'enum' => %w[
        architecture
        refactor
        bulk_patch
        test_generation
        summarization
        interactive_edit
      ]
    },
    'risk_level' => {
      'type' => 'string',
      'enum' => %w[low medium high]
    },
    'confidence' => {
      'type' => 'number',
      'minimum' => 0,
      'maximum' => 1
    },
    'slices' => {
      'type' => 'array',
      'items' => { 'type' => 'string' }
    }
  }
}.freeze
