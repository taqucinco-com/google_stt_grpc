import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { GoogleAuth } from 'google-auth-library'

const app = new Hono()

// GOOGLE_APPLICATION_CREDENTIALS(サービスアカウントJSONキーへのパス)を
// 環境変数から自動で読み込む(Application Default Credentials)。
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
})

app.get('/', (c) => {
  return c.text('hello, hono!')
})

app.get('/token', async (c) => {
  try {
    const client = await auth.getClient()
    const { token } = await client.getAccessToken()
    return c.json({ access_token: token })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'failed to issue access token' }, 500)
  }
})

serve({
  fetch: app.fetch,
  port: 8787
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`)
})
