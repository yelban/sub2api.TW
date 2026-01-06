import { createI18n } from 'vue-i18n'
import en from './locales/en'
import zhHans from './locales/zh-Hans'
import zhHant from './locales/zh-Hant'

const LOCALE_KEY = 'sub2api_locale'
const VALID_LOCALES = ['en', 'zh-Hans', 'zh-Hant'] as const
type ValidLocale = (typeof VALID_LOCALES)[number]

function getDefaultLocale(): ValidLocale {
  const saved = localStorage.getItem(LOCALE_KEY)

  // 遷移舊的 'zh' 設定到 'zh-Hans'
  if (saved === 'zh') {
    localStorage.setItem(LOCALE_KEY, 'zh-Hans')
    return 'zh-Hans'
  }

  if (saved && VALID_LOCALES.includes(saved as ValidLocale)) {
    return saved as ValidLocale
  }

  // 瀏覽器語言偵測
  const browserLang = navigator.language.toLowerCase()
  if (browserLang.startsWith('zh')) {
    // zh-TW, zh-HK, zh-MO, zh-Hant → 繁體
    if (
      ['zh-tw', 'zh-hk', 'zh-mo'].includes(browserLang) ||
      browserLang.includes('hant')
    ) {
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
  // 禁用 HTML 消息警告 - 引导步骤使用富文本内容（driver.js 支持 HTML）
  // 这些内容是内部定义的，不存在 XSS 风险
  warnHtmlMessage: false
})

export function setLocale(locale: string) {
  if (VALID_LOCALES.includes(locale as ValidLocale)) {
    i18n.global.locale.value = locale as ValidLocale
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
