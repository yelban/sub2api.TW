# 新增繁體中文介面 - i18n 實作指南

> 建立日期: 2026-01-07

## 決策摘要

| 項目 | 決定 | 說明 |
|------|------|------|
| 語言代碼 | `zh-Hans` / `zh-Hant` | 基於書寫系統 (BCP 47 標準) |
| 顯示名稱 | 「简体中文」/「繁體中文」| - |
| 旗幟 | 🇨🇳 / 🇹🇼 | - |
| 翻譯方式 | OpenCC 簡轉繁 + 人工校對 | 使用 `s2twp.json` 配置 |

---

## 背景: 中文語言代碼最佳實踐

### BCP 47 標準的兩種方式

| 方式 | 代碼範例 | 說明 |
|------|----------|------|
| **Script-based** | `zh-Hans`, `zh-Hant` | 基於書寫系統 (推薦) |
| **Region-based** | `zh-CN`, `zh-TW`, `zh-HK` | 基於地區 |

### 為什麼選擇 `zh-Hans` / `zh-Hant`

1. **不綁定地區**: 繁體中文使用者不只在台灣，還有香港、澳門、馬來西亞、海外華人社區
2. **語意清晰**: 明確表達「簡化字」vs「正體字/繁體字」
3. **W3C 建議**: W3C 建議中文使用 script subtag
4. **國際標準**: 符合 ISO 15924 script codes

### 瀏覽器語言偵測映射

```
zh-CN, zh-SG, zh-Hans, zh-Hans-* → zh-Hans (簡體)
zh-TW, zh-HK, zh-MO, zh-Hant, zh-Hant-* → zh-Hant (繁體)
zh (無後綴) → 預設為 zh-Hans
```

---

## 實作步驟

### Step 1: 修改 i18n 配置

**檔案:** `frontend/src/i18n/index.ts`

```typescript
import { createI18n } from 'vue-i18n'
import en from './locales/en'
import zhHans from './locales/zh-Hans'
import zhHant from './locales/zh-Hant'

const LOCALE_KEY = 'sub2api_locale'

function getDefaultLocale(): string {
  const saved = localStorage.getItem(LOCALE_KEY)

  // 遷移舊的 'zh' 設定
  if (saved === 'zh') {
    localStorage.setItem(LOCALE_KEY, 'zh-Hans')
    return 'zh-Hans'
  }

  if (saved && ['en', 'zh-Hans', 'zh-Hant'].includes(saved)) {
    return saved
  }

  // 瀏覽器語言偵測
  const browserLang = navigator.language.toLowerCase()
  if (browserLang.startsWith('zh')) {
    // zh-TW, zh-HK, zh-MO, zh-Hant → 繁體
    if (['zh-tw', 'zh-hk', 'zh-mo'].includes(browserLang) ||
        browserLang.includes('hant')) {
      return 'zh-Hant'
    }
    // zh-CN, zh-SG, zh-Hans, zh → 簡體
    return 'zh-Hans'
  }

  return 'en'
}

export const i18n = createI18n({
  legacy: false,
  locale: getDefaultLocale(),
  fallbackLocale: 'en',
  messages: {
    en,
    'zh-Hans': zhHans,
    'zh-Hant': zhHant
  },
  warnHtmlMessage: false
})

export function setLocale(locale: string) {
  if (['en', 'zh-Hans', 'zh-Hant'].includes(locale)) {
    i18n.global.locale.value = locale as 'en' | 'zh-Hans' | 'zh-Hant'
    localStorage.setItem(LOCALE_KEY, locale)
    document.documentElement.setAttribute('lang', locale)
  }
}

export function getLocale(): string {
  return i18n.global.locale.value
}

export const availableLocales = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'zh-Hans', name: '简体中文', flag: '🇨🇳' },
  { code: 'zh-Hant', name: '繁體中文', flag: '🇹🇼' }
]

export default i18n
```

### Step 2: 重命名簡體中文檔案

```bash
git mv frontend/src/i18n/locales/zh.ts frontend/src/i18n/locales/zh-Hans.ts
```

### Step 3: 建立繁體中文翻譯檔

使用 OpenCC 將簡體轉換為繁體 (台灣正體):

```bash
# 安裝 OpenCC (macOS)
brew install opencc

# 轉換 (使用 s2twp 配置: 簡體→繁體台灣 + 常用詞彙轉換)
opencc -i frontend/src/i18n/locales/zh-Hans.ts \
       -o frontend/src/i18n/locales/zh-Hant.ts \
       -c s2twp.json
```

**OpenCC 配置說明:**
- `s2twp.json`: 簡體到繁體 (台灣正體) + 常用詞彙轉換
  - 「软件」→「軟體」
  - 「内存」→「記憶體」
  - 「信息」→「資訊」
  - 「视频」→「影片」

**後續:** 人工校對確保用語自然

---

## 檔案變更清單

| 檔案 | 操作 |
|------|------|
| `frontend/src/i18n/index.ts` | 修改 |
| `frontend/src/i18n/locales/zh.ts` | 重命名為 `zh-Hans.ts` |
| `frontend/src/i18n/locales/zh-Hant.ts` | 新增 |

**不需修改:**
- `LocaleSwitcher.vue` - 自動使用新的 `availableLocales`
- 其他使用 `useI18n()` 的元件 - API 不變

---

## 向後相容性

- 舊的 `zh` localStorage 值會自動遷移到 `zh-Hans`
- 現有用戶體驗不受影響

---

## 測試項目

- [ ] 語言切換功能正常 (en ↔ zh-Hans ↔ zh-Hant)
- [ ] 瀏覽器自動偵測 (zh-TW → zh-Hant, zh-CN → zh-Hans)
- [ ] localStorage 舊值遷移 (zh → zh-Hans)
- [ ] HTML `lang` 屬性更新
- [ ] 所有翻譯 key 都有對應的繁體翻譯
