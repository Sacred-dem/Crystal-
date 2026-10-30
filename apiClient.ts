const API_URL = import.meta.env.VITE_API_URL || '/api'

export async function postChatMessage(payload: unknown) {
  const res = await fetch(`${API_URL}/chat/message`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    throw new Error(`Chat request failed: ${res.status}`)
  }
  return res.json()
}
