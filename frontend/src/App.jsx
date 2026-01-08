import { useState, useEffect } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''

function App() {
  const [messages, setMessages] = useState([])
  const [newMessage, setNewMessage] = useState('')

  const fetchMessages = async () => {
    const res = await fetch(`${API_URL}/api/messages`)
    const data = await res.json()
    setMessages(data)
  }

  useEffect(() => {
    fetchMessages()
  }, [])

  const addMessage = async (e) => {
    e.preventDefault()
    if (!newMessage.trim()) return
    await fetch(`${API_URL}/api/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: newMessage })
    })
    setNewMessage('')
    fetchMessages()
  }

  const deleteMessage = async (id) => {
    await fetch(`${API_URL}/api/messages/${id}`, { method: 'DELETE' })
    fetchMessages()
  }

  return (
    <div style={{ maxWidth: '600px', margin: '50px auto', fontFamily: 'Arial' }}>
      <h1>📝 AWS Demo App</h1>
      <p style={{ color: '#666' }}>Spring Boot + React + PostgreSQL</p>
      
      <form onSubmit={addMessage} style={{ marginBottom: '20px' }}>
        <input
          type="text"
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          placeholder="Enter a message..."
          style={{ padding: '10px', width: '300px', marginRight: '10px' }}
        />
        <button type="submit" style={{ padding: '10px 20px' }}>Add</button>
      </form>

      <ul style={{ listStyle: 'none', padding: 0 }}>
        {messages.map((msg) => (
          <li key={msg.id} style={{ 
            padding: '10px', 
            background: '#f5f5f5', 
            marginBottom: '8px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            borderRadius: '4px'
          }}>
            <span>{msg.content}</span>
            <button onClick={() => deleteMessage(msg.id)} style={{ color: 'red', border: 'none', cursor: 'pointer' }}>
              ✕
            </button>
          </li>
        ))}
      </ul>
      
      {messages.length === 0 && <p style={{ color: '#999' }}>No messages yet. Add one above!</p>}
    </div>
  )
}

export default App
