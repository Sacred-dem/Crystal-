const API_URL = import.meta.env.VITE_API_URL || '/api'

export async function transcribeVoice(audioBlob: Blob) {
  const form = new FormData()
  form.append('audio', audioBlob, 'voice.webm')

  const res = await fetch(`${API_URL}/voice/transcribe`, {
    method: 'POST',
    body: form,
  })
  if (!res.ok) {
    throw new Error(`Transcription failed: ${res.status}`)
  }
  return res.json()
}

export async function synthesizeVoice(text: string): Promise<Blob> {
  const res = await fetch(`${API_URL}/voice/synthesize`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  })
  if (!res.ok) {
    throw new Error(`Synthesis failed: ${res.status}`)
  }
  return res.blob()
}
