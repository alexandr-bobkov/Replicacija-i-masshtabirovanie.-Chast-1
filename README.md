# Домашнее задание к занятию «Репликация и масштабирование. Часть 1» - Бобков Александр


# 📑 Полное учебное руководство: Безопасная автоматизация репликации в MySQL и Docker

Данный документ содержит теоретический ответ на Задание 1, листинги всех конфигурационных файлов для Заданий 2 и 3*, а также простую пошаговую инструкцию по запуску.

---

## 📂 Структура папок вашего проекта

Чтобы магия автоматизации сработала, создайте на вашем сервере всего одну папку (например, `mysql-project`), а внутри неё — подпапку `init`. 

Разложите файлы ровно по этой схеме:
* `mysql-project/.env` — здесь хранятся пароли
* `mysql-project/docker-compose.yml` — главный сценарий Docker
* `mysql-project/master.cnf` — настройки Мастера (Задание 2)
* `mysql-project/slave.cnf` — настройки Слейва (Задание 2)
* `mysql-project/master1.cnf` — настройки Первого Мастера (Задание 3*)
* `mysql-project/master2.cnf` — настройки Второго Мастера (Задание 3*)
* `mysql-project/init/master-init.sql` — скрипт автозапуска для Мастера
* `mysql-project/init/slave-init.sql` — скрипт автозапуска для Слейва
* `mysql-project/init/mm1-init.sql` — скрипт автозапуска для Master-Master 1
* `mysql-project/init/mm2-init.sql` — скрипт автозапуска для Master-Master 2

---

## ЧАСТЬ 1: Теория и ответы на задания

### Задание 1: Различия режимов репликации master-slave, master-master

Репликация — это процесс копирования данных с одного сервера на другой в режиме реального времени.

#### 1. Режим master-slave (Главный — Подчинённый)
В этой схеме роли серверов строго разделены:
* **Master (Главный):** Принимает абсолютно любые запросы от сайта или пользователя: и на чтение, и на изменение данных. Все новые записи он заносит в свой бинарный лог.
* **Slave (Подчинённый):** Работает строго в режиме «Только для чтения». Он непрерывно читает лог Мастера по сети и повторяют все изменения у себя.
* **Главный плюс:** Идеально распределяет нагрузку на чтение (пользователи смотрят товары на Слейве, а оформляют заказы на Мастере).
* **Главный минус:** Если Мастер «упадет», сайт временно перестает принимать новые записи, пока администратор вручную не сделает Слейв новым главным сервером.

#### 2. Режим master-master (Главный — Главный)
В этой схеме оба сервера являются абсолютно равноправными:
* Оба сервера одновременно могут принимать и чтение, и запись. Изменения передаются перекрестно друг другу в обоих направлениях.
* **Главный плюс:** Высокая отказоустойчивость. Если один сервер сгорит, сайт мгновенно переключится на запись во второй без пауз в работе.
* **Главный минус:** Сложная архитектура. Возникает огромный риск **конфликтов репликации**, если одну и ту же строчку изменят одновременно на двух разных серверах (база запутается, какое изменение верное).

---

## ЧАСТЬ 2: Исходный код конфигурационных файлов

### 📄 Файл 1: `.env`
```env
MYSQL_ROOT_PASSWORD=supersecretpass2026
MYSQL_REPL_USER=repl_user
MYSQL_REPL_PASSWORD=my_secure_repl_password_123
```

### 📄 Файл 2: `master.cnf`
```ini
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog_do_db = sakila
```

### 📄 Файл 3: `slave.cnf`
```ini
[mysqld]
server-id = 2
relay-log = mysql-relay-bin
read_only = 1
```

### 📄 Файл 4: `master1.cnf`
```ini
[mysqld]
server-id = 10
log-bin = mysql-bin-m1
auto_increment_increment = 2
auto_increment_offset = 1
```

### 📄 Файл 5: `master2.cnf`
```ini
[mysqld]
server-id = 20
log-bin = mysql-bin-m2
auto_increment_increment = 2
auto_increment_offset = 2
```

---

## ЧАСТЬ 3: SQL-скрипты автоматической инициализации (Папка `init`)

Каждый файл ниже содержит комментарии, объясняющие новичку, зачем нужна эта команда.

### 📄 Файл 6: `init/master-init.sql`
```sql
-- Полностью удаляем старого пользователя, если он остался в памяти
DROP USER IF EXISTS 'repl_user'@'%';

-- Создаем пользователя репликации со старым совместимым шифрованием пароля.
-- Новые версии MySQL используют caching_sha2, который слейв без SSL не примет.
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';

-- Выдаем права на чтение бинарных логов
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

-- Сохраняем настройки в системную память
FLUSH PRIVILEGES;
```

### 📄 Файл 7: `init/slave-init.sql`
```sql
-- При первом «чистом» старте контейнеров имя файла лога Мастера ВСЕГДА называется mysql-bin.000001, 
-- а стартовая позиция ВСЕГДА равна 157. Мы используем этот стандарт для автоматизации.
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=157;

-- Запускаем фоновые потоки скачивания данных
START SLAVE;
```

### 📄 Файл 8: `init/mm1-init.sql`
```sql
-- Настраиваем первый сервер из пары Главный-Главный
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- Закольцовываем репликацию: указываем первому серверу скачивать логи со второго
CHANGE MASTER TO 
  MASTER_HOST='mm-master2',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin-m2.000001',
  MASTER_LOG_POS=157;

START SLAVE;
```

### 📄 Файл 9: `init/mm2-init.sql`
```sql
-- Настраиваем второй сервер из пары Главный-Главный
DROP USER IF EXISTS 'repl_user'@'%';
CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'my_secure_repl_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;

-- Направляем этот сервер на получение бинарных логов из первого
CHANGE MASTER TO 
  MASTER_HOST='mm-master1',
  MASTER_USER='repl_user',
  MASTER_PASSWORD='my_secure_repl_password_123',
  MASTER_LOG_FILE='mysql-bin-m1.000001',
  MASTER_LOG_POS=157;

START SLAVE;
```

---

## ЧАСТЬ 4: Разбор сценария `docker-compose.yml`

Ниже представлен полный файл конфигурации. К каждому блоку и параметру добавлено подробное текстовое описание, чтобы вы понимали, за что отвечает каждая строчка.

### Что значат основные директивы верхнего уровня:
* **`version: '3.8'`** — указывает Docker Compose, какую версию стандартов использовать для чтения этого файла.
* **`networks`** — раздел для настройки сети. Здесь мы создаем общую изолированную виртуальную сеть `replication_net` с драйвером `bridge`. Этот «мост» позволяет контейнерам общаться друг с другом напрямую по текстовым именам сервисов (как по доменным именам в интернете), полностью заменяя сложные IP-адреса.
* **`services`** — главный раздел, где перечисляются все запускаемые контейнеры (серверы базы данных).

```yaml
version: '3.8'

networks:
  replication_net:
    driver: bridge

services:
  # ============================================================================
  # ИНФРАСТРУКТУРА ДЛЯ ЗАДАНИЯ 2: MASTER-SLAVE
  # ============================================================================
  
  # mysql-master — имя сервиса главного сервера в нашей внутренней сети Docker
  mysql-master:
    image: mysql:8.0 # Указывает Docker скачать официальный готовый образ MySQL 8.0 с Docker Hub
    container_name: mysql-master # Фиксирует имя контейнера для команд в консоли (например, docker logs)
    
    # command принудительно переопределяет стартовую инструкцию. Она заставляет MySQL 8.0
    # использовать старый метод проверки паролей. Без этого флага DBeaver выдаст ошибку авторизации.
    command: --default-authentication-plugin=mysql_native_password
    
    environment:
      # Настройка переменных окружения. Конструкция ${...} автоматически считывает 
      # пароль "supersecretpass2026" из нашего скрытого файла .env, обеспечивая безопасность.
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      
    ports:
      - "3306:3306" # Проброс портов наружу: [Порт на вашем основном ПК] : [Внутренний порт контейнера].
                    # Главный сервер будет доступен на стандартном порту 3306.
                    
    volumes:
      # Volumes (тома) монтируют папки с вашего компьютера внутрь контейнера.
      # Слева указан ваш локальный файл, справа — папка внутри MySQL, куда он подложится.
      - ./master.cnf:/etc/mysql/conf.d/master.cnf
      
      # Папка /docker-entrypoint-initdb.d/ — это встроенный инструмент автоматизации Docker.
      # Все файлы .sql, которые мы туда прокидываем, Docker САМ запускает при первом старте базы.
      - ./init/master-init.sql:/docker-entrypoint-initdb.d/master-init.sql
      
    networks:
      - replication_net # Подключает Мастер к нашей общей изолированной сети

  # mysql-slave — подчиненный сервер (реплика)
  mysql-slave:
    image: mysql:8.0
    container_name: mysql-slave
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3307:3306" # Пробрасывает Слейв наружу на соседний порт 3307, чтобы не было конфликта с Мастером
    volumes:
      - ./slave.cnf:/etc/mysql/conf.d/slave.cnf
      - ./init/slave-init.sql:/docker-entrypoint-initdb.d/slave-init.sql
    depends_on:
      - mysql-master # Инструкция указывает Docker запускать Слейв строго ПОСЛЕ старта Мастера
    networks:
      - replication_net

  # ============================================================================
  # ИНФРАСТРУКТУРА ДЛЯ ЗАДАНИЯ 3*: MASTER-MASTER
  # ============================================================================
  
  # mm-master1 — первый главный сервер из пары Master-Master
  # Первый сервер из пары Master-Master
  mm-master1:
    image: mysql:8.0
    container_name: mm-master1
    command: --default-authentication-plugin=mysql_native_password
    environment:
      # Вот эта строчка: задает root-пароль из файла .env
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      # Вот эта строчка: пробрасывает порт наружу на 3308
      - "3308:3306" 
    volumes:
      # Вот эти строчки: подключают файл настроек и скрипт автозапуска
      - ./master1.cnf:/etc/mysql/conf.d/master1.cnf
      - ./init/mm1-init.sql:/docker-entrypoint-initdb.d/mm1-init.sql
    networks:
      # Вот эта строчка: подключает сервер к общей сети
      - replication_net

