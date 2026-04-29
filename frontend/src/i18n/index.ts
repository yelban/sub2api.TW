import { createI18n } from 'vue-i18n'

type LocaleCode = 'en' | 'zh-Hans' | 'zh-Hant'

type LocaleMessages = Record<string, any>

const LOCALE_KEY = 'sub2api_locale'
const DEFAULT_LOCALE: LocaleCode = 'en'

const localeLoaders: Record<LocaleCode, () => Promise<{ default: LocaleMessages }>> = {
  en: () => import('./locales/en'),
  'zh-Hans': () => import('./locales/zh-Hans'),
  'zh-Hant': () => import('./locales/zh-Hant')
}

function isLocaleCode(value: string): value is LocaleCode {
  return value === 'en' || value === 'zh-Hans' || value === 'zh-Hant'
}

function getDefaultLocale(): LocaleCode {
  const saved = localStorage.getItem(LOCALE_KEY)

  // 遷移舊的 'zh' 設定到 'zh-Hans'
  if (saved === 'zh') {
    localStorage.setItem(LOCALE_KEY, 'zh-Hans')
    return 'zh-Hans'
  }

  if (saved && isLocaleCode(saved)) {
    return saved
  }

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

  return DEFAULT_LOCALE
}

export const i18n = createI18n({
  legacy: false,
  locale: getDefaultLocale(),
  fallbackLocale: DEFAULT_LOCALE,
  messages: {},
  // 禁用 HTML 訊息警告 - 引導步驟使用富文字內容（driver.js 支援 HTML）
  // 這些內容是內部定義的，不存在 XSS 風險
  warnHtmlMessage: false
})

const loadedLocales = new Set<LocaleCode>()

export async function loadLocaleMessages(locale: LocaleCode): Promise<void> {
  if (loadedLocales.has(locale)) {
    return
  }

  const loader = localeLoaders[locale]
  const module = await loader()
  i18n.global.setLocaleMessage(locale, module.default)
  loadedLocales.add(locale)
}

export async function initI18n(): Promise<void> {
  const current = getLocale()
  await loadLocaleMessages(current)
  document.documentElement.setAttribute('lang', current)
}

export async function setLocale(locale: string): Promise<void> {
  if (!isLocaleCode(locale)) {
    return
  }

  await loadLocaleMessages(locale)
  i18n.global.locale.value = locale
  localStorage.setItem(LOCALE_KEY, locale)
  document.documentElement.setAttribute('lang', locale)

  // 同步更新瀏覽器頁籤標題，使其跟隨語言切換
  const { resolveDocumentTitle } = await import('@/router/title')
  const { default: router } = await import('@/router')
  const { useAppStore } = await import('@/stores/app')
  const route = router.currentRoute.value
  const appStore = useAppStore()
  document.title = resolveDocumentTitle(route.meta.title, appStore.siteName, route.meta.titleKey as string)
}

export function getLocale(): LocaleCode {
  const current = i18n.global.locale.value
  return isLocaleCode(current) ? current : DEFAULT_LOCALE
}

export const availableLocales = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'zh-Hans', name: '简体中文', flag: '🇨🇳' },
  { code: 'zh-Hant', name: '繁體中文', flag: '🇹🇼' }
] as const

export default i18n
