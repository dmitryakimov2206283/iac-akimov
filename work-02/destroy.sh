#!/usr/bin/env bash
set -euo pipefail

PREFIX=akimov-04
VM_COUNT=$(yc compute instance list --format json | jq -r '.[].name' \
    | grep $PREFIX-app- | wc -l)

echo "=== Начало безопасной очистки ресурсов ==="

# 1. Удаление Сетевого Балансировщика
if yc load-balancer network-load-balancer get "$PREFIX-lb" &>/dev/null; then
    echo "Удаление балансировщика: $PREFIX-lb..."
    yc load-balancer network-load-balancer delete "$PREFIX-lb"
else
    echo "Балансировщик $PREFIX-lb не найден, пропускаем."
fi

# 2. Удаление Целевой Группы
if yc load-balancer target-group get "$PREFIX-tg" &>/dev/null; then
    echo "Удаление целевой группы: $PREFIX-tg..."
    yc load-balancer target-group delete "$PREFIX-tg"
else
    echo "Целевая группа $PREFIX-tg не найдена, пропускаем."
fi

# 3. Удаление Виртуальных Машин
for i in $(seq 1 "$VM_COUNT"); do
    VM_NAME="$PREFIX-app-$i"
    if yc compute instance get "$VM_NAME" &>/dev/null; then
        echo "Удаление ВМ: $VM_NAME..."
        yc compute instance delete "$VM_NAME"
    else
        echo "ВМ $VM_NAME не найдена, пропускаем."
    fi
done

# 4. Удаление Дополнительного Диска
if yc compute disk get "$PREFIX-data" &>/dev/null; then
    echo "Удаление дополнительного диска: $PREFIX-data..."
    yc compute disk delete "$PREFIX-data"
else
    echo "Диск $PREFIX-data не найден, пропускаем."
fi

# 5. Удаление Подсетей
if yc vpc subnet get "$PREFIX-subnet-a" &>/dev/null; then
    echo "Удаление подсети: $PREFIX-subnet-a..."
    yc vpc subnet delete "$PREFIX-subnet-a"
else
    echo "Подсеть $PREFIX-subnet-a не найдена, пропускаем."
fi

if yc vpc subnet get "$PREFIX-subnet-b" &>/dev/null; then
    echo "Удаление подсети: $PREFIX-subnet-b..."
    yc vpc subnet delete "$PREFIX-subnet-b"
else
    echo "Подсеть $PREFIX-subnet-b не найдена, пропускаем."
fi

# 6. Удаление Сети
if yc vpc network get "$PREFIX-net" &>/dev/null; then
    echo "Удаление сети: $PREFIX-net..."
    yc vpc network delete "$PREFIX-net"
else
    echo "Сеть $PREFIX-net не найдена, пропускаем."
fi

echo "=== Очистка ресурсов успешно завершена ==="



