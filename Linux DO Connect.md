# Linux DO Connect

OAuth（Open Authorization）是一個開放的網路授權標準，目前最新版本為 OAuth 2.0。我們日常使用的第三方登入（如 Google 帳號登入）就採用了該標準。OAuth 允許使用者授權第三方應用訪問儲存在其他服務提供商（如 Google）上的資訊，無需在不同平臺上重複填寫註冊資訊。使用者授權後，平臺可以直接訪問使用者的帳戶資訊進行身份驗證，而使用者無需向第三方應用提供密碼。

目前系統已實現完整的 OAuth2 授權碼（code）方式鑑權，但介面等配套功能還在持續完善中。讓我們一起打造一個更完善的共享方案。

## 基本介紹

這是一套標準的 OAuth2 鑑權系統，可以讓開發者共享論壇的使用者基本資訊。

- 可獲取欄位：

| 引數              | 說明                            |
| ----------------- | ------------------------------- |
| `id`              | 使用者唯一標識（不可變）          |
| `username`        | 論壇使用者名稱                      |
| `name`            | 論壇使用者暱稱（可變）            |
| `avatar_template` | 使用者頭像模板URL（支援多種尺寸） |
| `active`          | 帳號活躍狀態                    |
| `trust_level`     | 信任等級（0-4）                 |
| `silenced`        | 禁言狀態                        |
| `external_ids`    | 外部ID關聯資訊                  |
| `api_key`         | API訪問金鑰                     |

透過這些資訊，公益網站/介面可以實現：

1. 基於 `id` 的服務頻率限制
2. 基於 `trust_level` 的服務額度分配
3. 基於使用者資訊的濫用舉報機制

## 相關端點

- Authorize 端點： `https://connect.linux.do/oauth2/authorize`
- Token 端點：`https://connect.linux.do/oauth2/token`
- 使用者資訊 端點：`https://connect.linux.do/api/user`

## 申請使用

- 訪問 [Connect.Linux.Do](https://connect.linux.do/) 申請接入你的應用。

![linuxdoconnect_1](https://wiki.linux.do/_next/image?url=%2Flinuxdoconnect_1.png&w=1080&q=75)

- 點選 **`我的應用接入`** - **`申請新接入`**，填寫相關資訊。其中 **`回撥地址`** 是你的應用接收使用者資訊的地址。

![linuxdoconnect_2](https://wiki.linux.do/_next/image?url=%2Flinuxdoconnect_2.png&w=1080&q=75)

- 申請成功後，你將獲得 **`Client Id`** 和 **`Client Secret`**，這是你應用的唯一身份憑證。

![linuxdoconnect_3](https://wiki.linux.do/_next/image?url=%2Flinuxdoconnect_3.png&w=1080&q=75)

## 接入 Linux Do

JavaScript
```JavaScript
// 安裝第三方請求庫（或使用原生的 Fetch API），本例中使用 axios
// npm install axios

// 透過 OAuth2 獲取 Linux Do 使用者資訊的參考流程
const axios = require('axios');
const readline = require('readline');

// 配置資訊（建議透過環境變數配置，避免使用硬編碼）
const CLIENT_ID = '你的 Client ID';
const CLIENT_SECRET = '你的 Client Secret';
const REDIRECT_URI = '你的回撥地址';
const AUTH_URL = 'https://connect.linux.do/oauth2/authorize';
const TOKEN_URL = 'https://connect.linux.do/oauth2/token';
const USER_INFO_URL = 'https://connect.linux.do/api/user';

// 第一步：生成授權 URL
function getAuthUrl() {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: 'user'
  });

  return `${AUTH_URL}?${params.toString()}`;
}

// 第二步：獲取 code 引數
function getCode() {
  return new Promise((resolve) => {
    // 本例中使用終端輸入來模擬流程，僅供本地測試
    // 請在實際應用中替換為真實的處理邏輯
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question('從回撥 URL 中提取出 code，貼上到此處並按回車：', (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// 第三步：使用 code 引數獲取訪問令牌
async function getAccessToken(code) {
  try {
    const form = new URLSearchParams({
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      code: code,
      redirect_uri: REDIRECT_URI,
      grant_type: 'authorization_code'
    }).toString();

    const response = await axios.post(TOKEN_URL, form, {
      // 提醒：需正確配置請求頭，否則無法正常獲取訪問令牌
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      }
    });

    return response.data;
  } catch (error) {
    console.error(`獲取訪問令牌失敗：${error.response ? JSON.stringify(error.response.data) : error.message}`);
    throw error;
  }
}

// 第四步：使用訪問令牌獲取使用者資訊
async function getUserInfo(accessToken) {
  try {
    const response = await axios.get(USER_INFO_URL, {
      headers: {
        Authorization: `Bearer ${accessToken}`
      }
    });

    return response.data;
  } catch (error) {
    console.error(`獲取使用者資訊失敗：${error.response ? JSON.stringify(error.response.data) : error.message}`);
    throw error;
  }
}

// 主流程
async function main() {
  // 1. 生成授權 URL，前端引導使用者訪問授權頁
  const authUrl = getAuthUrl();
  console.log(`請訪問此 URL 授權：${authUrl}
`);

  // 2. 使用者授權後，從回撥 URL 獲取 code 引數
  const code = await getCode();

  try {
    // 3. 使用 code 引數獲取訪問令牌
    const tokenData = await getAccessToken(code);
    const accessToken = tokenData.access_token;

    // 4. 使用訪問令牌獲取使用者資訊
    if (accessToken) {
      const userInfo = await getUserInfo(accessToken);
      console.log(`
獲取使用者資訊成功：${JSON.stringify(userInfo, null, 2)}`);
    } else {
      console.log(`
獲取訪問令牌失敗：${JSON.stringify(tokenData)}`);
    }
  } catch (error) {
    console.error('發生錯誤：', error);
  }
}
```
Python
```python
# 安裝第三方請求庫，本例中使用 requests
# pip install requests

# 透過 OAuth2 獲取 Linux Do 使用者資訊的參考流程
import requests
import json

# 配置資訊（建議透過環境變數配置，避免使用硬編碼）
CLIENT_ID = '你的 Client ID'
CLIENT_SECRET = '你的 Client Secret'
REDIRECT_URI = '你的回撥地址'
AUTH_URL = 'https://connect.linux.do/oauth2/authorize'
TOKEN_URL = 'https://connect.linux.do/oauth2/token'
USER_INFO_URL = 'https://connect.linux.do/api/user'

# 第一步：生成授權 URL
def get_auth_url():
    params = {
        'client_id': CLIENT_ID,
        'redirect_uri': REDIRECT_URI,
        'response_type': 'code',
        'scope': 'user'
    }
    auth_url = f"{AUTH_URL}?{'&'.join(f'{k}={v}' for k, v in params.items())}"
    return auth_url

# 第二步：獲取 code 引數
def get_code():
    # 本例中使用終端輸入來模擬流程，僅供本地測試
    # 請在實際應用中替換為真實的處理邏輯
    return input('從回撥 URL 中提取出 code，貼上到此處並按回車：').strip()

# 第三步：使用 code 引數獲取訪問令牌
def get_access_token(code):
    try:
        data = {
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET,
            'code': code,
            'redirect_uri': REDIRECT_URI,
            'grant_type': 'authorization_code'
        }
        # 提醒：需正確配置請求頭，否則無法正常獲取訪問令牌
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
        }
        response = requests.post(TOKEN_URL, data=data, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"獲取訪問令牌失敗：{e}")
        return None

# 第四步：使用訪問令牌獲取使用者資訊
def get_user_info(access_token):
    try:
        headers = {
            'Authorization': f'Bearer {access_token}'
        }
        response = requests.get(USER_INFO_URL, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"獲取使用者資訊失敗：{e}")
        return None

# 主流程
if __name__ == '__main__':
    # 1. 生成授權 URL，前端引導使用者訪問授權頁
    auth_url = get_auth_url()
    print(f'請訪問此 URL 授權：{auth_url}
')

    # 2. 使用者授權後，從回撥 URL 獲取 code 引數
    code = get_code()

    # 3. 使用 code 引數獲取訪問令牌
    token_data = get_access_token(code)
    if token_data:
        access_token = token_data.get('access_token')

        # 4. 使用訪問令牌獲取使用者資訊
        if access_token:
            user_info = get_user_info(access_token)
            if user_info:
                print(f"
獲取使用者資訊成功：{json.dumps(user_info, indent=2)}")
            else:
                print("
獲取使用者資訊失敗")
        else:
            print(f"
獲取訪問令牌失敗：{json.dumps(token_data, indent=2)}")
    else:
        print("
獲取訪問令牌失敗")
```
PHP
```php
// 透過 OAuth2 獲取 Linux Do 使用者資訊的參考流程

// 配置資訊
$CLIENT_ID = '你的 Client ID';
$CLIENT_SECRET = '你的 Client Secret';
$REDIRECT_URI = '你的回撥地址';
$AUTH_URL = 'https://connect.linux.do/oauth2/authorize';
$TOKEN_URL = 'https://connect.linux.do/oauth2/token';
$USER_INFO_URL = 'https://connect.linux.do/api/user';

// 生成授權 URL
function getAuthUrl($clientId, $redirectUri) {
    global $AUTH_URL;
    return $AUTH_URL . '?' . http_build_query([
        'client_id' => $clientId,
        'redirect_uri' => $redirectUri,
        'response_type' => 'code',
        'scope' => 'user'
    ]);
}

// 使用 code 引數獲取使用者資訊（合併獲取令牌和獲取使用者資訊的步驟）
function getUserInfoWithCode($code, $clientId, $clientSecret, $redirectUri) {
    global $TOKEN_URL, $USER_INFO_URL;

    // 1. 獲取訪問令牌
    $ch = curl_init($TOKEN_URL);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'client_id' => $clientId,
        'client_secret' => $clientSecret,
        'code' => $code,
        'redirect_uri' => $redirectUri,
        'grant_type' => 'authorization_code'
    ]));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/x-www-form-urlencoded',
        'Accept: application/json'
    ]);

    $tokenResponse = curl_exec($ch);
    curl_close($ch);

    $tokenData = json_decode($tokenResponse, true);
    if (!isset($tokenData['access_token'])) {
        return ['error' => '獲取訪問令牌失敗', 'details' => $tokenData];
    }

    // 2. 獲取使用者資訊
    $ch = curl_init($USER_INFO_URL);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $tokenData['access_token']
    ]);

    $userResponse = curl_exec($ch);
    curl_close($ch);

    return json_decode($userResponse, true);
}

// 主流程
// 1. 生成授權 URL
$authUrl = getAuthUrl($CLIENT_ID, $REDIRECT_URI);
echo "<a href='$authUrl'>使用 Linux Do 登入</a>";

// 2. 處理回撥並獲取使用者資訊
if (isset($_GET['code'])) {
    $userInfo = getUserInfoWithCode(
        $_GET['code'],
        $CLIENT_ID,
        $CLIENT_SECRET,
        $REDIRECT_URI
    );

    if (isset($userInfo['error'])) {
        echo '錯誤: ' . $userInfo['error'];
    } else {
        echo '歡迎, ' . $userInfo['name'] . '!';
        // 處理使用者登入邏輯...
    }
}
```

## 使用說明

### 授權流程

1. 使用者點選應用中的’使用 Linux Do 登入’按鈕
2. 系統將使用者重定向至 Linux Do 的授權頁面
3. 使用者完成授權後，系統自動重定向回應用並攜帶授權碼
4. 應用使用授權碼獲取訪問令牌
5. 使用訪問令牌獲取使用者資訊

### 安全建議

- 切勿在前端程式碼中暴露 Client Secret
- 對所有使用者輸入資料進行嚴格驗證
- 確保使用 HTTPS 協議傳輸資料
- 定期更新並妥善保管 Client Secret