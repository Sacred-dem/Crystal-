export type ChatRequest = {
  session_id: string
  user_id?: string
  message: string
  mode?: 'auto' | 'offline' | 'online'
  response_format?: 'text' | 'rich' | 'voice' | 'chart'
}

export type ChatResponse = {
  message_id: string
  assistant_text: string
  mode_used: string
  artifacts: Array<{ type: string; id: string; title?: string }>
  citations: unknown[]
  memory_updates: unknown[]
  warnings: string[]
}
