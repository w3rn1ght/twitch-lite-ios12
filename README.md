# Twitch Lite (iOS 12)

[![Build Twitch Lite](https://github.com/w3rn1ght/twitch-lite-ios12/actions/workflows/build.yml/badge.svg)](https://github.com/w3rn1ght/twitch-lite-ios12/actions/workflows/build.yml)

Нативный клиент Twitch для джейлбрейкнутого iOS 12. Написан на Objective-C/UIKit,
собирается через Theos и ставится как `.deb` в `/Applications/TwitchLite.app`.

Интерфейс на русском, тёмная тема и палитра повторяют официальное приложение
Twitch (`#0e0e10`, `#18181b`, `#9147ff`).

## Скачать готовый .deb

Готовые сборки лежат в [Releases](https://github.com/w3rn1ght/twitch-lite-ios12/releases):
`com.w3rn1ght.twitchlite_<версия>_iphoneos-arm.deb`.

## Возможности

- **Вход в аккаунт Twitch** — веб-логин в `WKWebView` с автоматическим
  перехватом cookie `auth-token`, плюс ручной ввод токена как резервный способ.
- **Главная** — как в официальном приложении: большой карусельный баннер с
  топовыми стримами, ряд «Прямая трансляция на Twitch» с карточками и ряд
  «Категории, которые могут вам понравиться».
- **Подписки** — каналы, на которые вы подписаны, разделённые на «В эфире» и
  «Не в эфире», с превью, числом зрителей и категорией.
- **Поиск** — каналы, категории и стримы по запросу, а без запроса — популярные
  категории для быстрого старта.
- **Избранное** — собственный список каналов (хранится локально в
  `NSUserDefaults`), тоже с разделением на live/offline.
- **Профиль** — аватар, баннер, описание, счётчики, обновление данных, выход из
  аккаунта и ссылки на разделы приложения.
- **Просмотр стримов** — HLS через `AVPlayer`: получение playback-токена,
  сборка `usher.ttvnw.net` m3u8, пауза, mute, полноэкранный режим через
  `AVPlayerViewController`, избранное и «поделиться» прямо с экрана канала.
- **Рабочий чат** — IRC-over-WebSocket (`wss://irc-ws.chat.twitch.tv:443`) поверх
  скрытого `WKWebView`, с бейджами, цветами ников, emotes, рендером
  `/me`-сообщений, отправкой сообщений (включая кириллицу) и
  автопереподключением.
- **Страницы категорий** — список стримов выбранной игры с шапкой-артом.

## Требования

- iOS 12.0–12.4 (таргет `iphone:clang:12.4:12.0`, `arm64`).
- Джейлбрейк (unc0ver / checkra1n / Chimera и т.п.).
- Для сборки: [Theos](https://theos.dev) + iOS 12.4 SDK, macOS или Linux/WSL.

## Сборка

### Локально

```sh
export THEOS=~/theos
export THEOS_MAKE_PATH=$THEOS/makefiles
make package FINALPACKAGE=1
```

Готовый пакет появится в `packages/com.w3rn1ght.twitchlite_1.0.0_iphoneos-arm.deb`.

Скрипт-обёртка (выставляет права на maintainer-скрипты и запускает сборку):

```sh
./package.sh
```

### GitHub Actions

В репозитории есть workflow `.github/workflows/build.yml`: он поднимает
macOS-раннер, ставит Theos и iOS 12.4 SDK, собирает `.deb` и складывает его в
артефакты. При пуше тега вида `v1.0.0` пакет автоматически прикрепляется к
релизу.

Запуск вручную: **Actions → Build Twitch Lite → Run workflow**.

## Установка

```sh
scp packages/*.deb root@<ipadress>:/var/root/
ssh root@<ipadress>
dpkg -i /var/root/com.w3rn1ght.twitchlite_1.0.0_iphoneos-arm.deb
```

`postinst` сам вызывает `uicache` и `sbreload`, иконка появляется на домашнем
экране. Удаление — обычным `dpkg -r com.w3rn1ght.twitchlite`.

## Вход в аккаунт

1. При первом запуске открывается экран логина.
2. Войдите в аккаунт Twitch в открывшемся окне (2FA поддерживается — это
   обычная веб-страница).
3. После успешного входа приложение само прочитает cookie `auth-token`,
   проверит токен через GraphQL и закроет окно.
4. Если автоматический перехват не сработал, нажмите «Ввести токен вручную» и
   вставьте значение cookie `auth-token` (без префикса `oauth:`).

Логин можно закрыть и browse-ить анонимно: экраны, требующие аккаунт, покажут
кнопку входа.

Токен хранится в Keychain (service `com.w3rn1ght.twitchlite`), профиль — в
`NSUserDefaults`. Выход из аккаунта очищает и то, и другое.

## Чат

Чат работает через Twitch IRC WebSocket. Так как в iOS 12 нет удобного
системного WebSocket-клиента, соединение поднимается внутри скрытого
`WKWebView`: JS открывает сокет, а нативная часть общается с ним через
`WKScriptMessageHandler`. Сообщения кодируются в base64 и декодируются через
`TextDecoder`, поэтому кириллица не ломается.

- Для чтения чата логин не обязателен — используется анонимный `justinfanNNNNN`.
- Для отправки сообщений нужен вход в аккаунт (иначе показывается предложение
  войти).
- При `RECONNECT` от Twitch соединение пересоздаётся автоматически.
- Запрашиваются только capabilities `twitch.tv/tags` и `twitch.tv/commands`.

## Если не грузятся картинки

Профиль → **Диагностика** — покажет версию iOS, состояние GraphQL API и ответы
CDN для аватара и обложки. Если CDN отвечает ошибкой, картинки блокирует сеть
или VPN, а не приложение.

Загрузчик изображений сначала идёт через `NSURLSession` с браузерным
`User-Agent` и `Referer`, а при ошибке автоматически повторяет запрос через
`WKWebView` (сеть WebKit), поэтому картинки появляются даже там, где прямой
запрос блокируется. Профиль → **Сбросить кэш картинок** очищает кэш.

## Архитектура

```
Sources/
├── main.m, TVAppDelegate.*          точка входа, появление окна, тёмная тема
├── TVMainViewController.*           UITabBarController, wordmark, стили баров
├── TVHomeViewController.*           вкладка «Главная» (баннер + ряды карточек)
├── TVHomeViews.*                    баннер-карусель, карточки стримов и категорий
├── TVStreamListViewController.*     список стримов для «Показать больше»
├── TVTheme.*                        палитра, шрифты, форматирование чисел, стили
├── TVIcons.*                        иконки, нарисованные кодом (template images)
├── TVModels.*                       TVUser / TVStream / TVGame / TVSearchResults
├── TVSession.*                      состояние логина, Keychain, избранное
├── TVAPI.*                          GraphQL-запросы и сборка playback-URL
├── TVImageLoader.*                  кэш картинок + TVRemoteImageView
├── TVCommonViews.*                  аватар, бейджи, пилюли, empty state, спиннер
├── TVStreamCell.*, TVChannelCell.*, TVGameCell.*
├── TVFollowingViewController.*      вкладка «Подписки»
├── TVSearchViewController.*         вкладка «Поиск»
├── TVFavoritesViewController.*      вкладка «Избранное»
├── TVProfileViewController.*        вкладка «Профиль»
├── TVChannelViewController.*        плеер + информация о канале
├── TVCategoryViewController.*       стримы категории
├── TVChatConnection.*               IRC-мост через WKWebView
├── TVChatViewController.*           UI чата
├── TVChatMessage.*, TVChatMessageCell.*  парсинг IRC-тегов, emotes, отрисовка
└── TVLoginViewController.*          веб-логин и ручной токен
```

### Как получаются данные

Все запросы идут в приватный веб-API Twitch:

- endpoint: `https://gql.twitch.tv/gql`
- заголовки: `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko`,
  `Authorization: OAuth <token>` (когда пользователь залогинен)

Используемые операции: текущий пользователь, `follows(first: 100)`, топ-стримы,
популярные игры, `searchFor` (channels + games), `users(logins:)`,
`game(name:)` + `streams`, `streamPlaybackAccessToken`.

Playback: из `streamPlaybackAccessToken` берутся `value` и `signature`, из них
собирается ссылка на `usher.ttvnw.net/api/channel/hls/<login>.m3u8`, которую
скармливаем `AVPlayer`.

## Ограничения

- Проект собирается под iOS 12; на iOS 13+ не тестировался.
- Используется недокументированный веб-API Twitch: запросы и Client-ID могут
  измениться в любой момент, и тогда часть экранов перестанет грузиться.
- Подписки (платные) не отображаются отдельным списком — вкладка «Подписки»
  показывает каналы из `follows`.
- Запись стрима, клипы, рейды, выбор качества и прочие второстепенные функции
  официального клиента не реализованы.
- Чат не поддерживает пикер emotes и отправку `/me`: сообщения уходят обычным
  текстом, а `/me`-сообщения других участников отображаются корректно.

## Лицензия и правовая заметка

Проект учебный и не связан с Twitch Interactive. «Twitch» и логотип принадлежат
Twitch Interactive, Inc. Использование приватного API может нарушать условия
предоставления услуг Twitch — используйте на свой риск.
