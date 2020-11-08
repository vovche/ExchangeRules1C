﻿<#
.SYNOPSIS
Версионирование правил обмена 1С

.LINK
https://github.com/bf0rce/ExchangeRules1C

.DESCRIPTION
Скрипт для сбора xml-файла Правил обмена 1С в единый файл из иерархической структуры каталогов и файлов.

.EXAMPLE
.\CollectExchangeRules.ps1

.NOTES
Вызов функций в виде "MyFunc -Par1 Value1 -Par2 Value2" принципиален. Только в таком случае параметры корректно 
передаются в функцию, могут быть изменены в ней и возвращены обратно в измененном состоянии.
#>

function СобратьКоллекциюОбъектов($ИсходныйЭлемент, $КаталогРодителя) {
	
	$КаталогРодителяСуществует = Test-Path -Path $КаталогРодителя
	if ( $КаталогРодителяСуществует -eq $false ) {
		return
	}

	$КаталогГруппыПравил = Join-Path -Path $КаталогРодителя -ChildPath "Группа"
	$КаталогГруппыПравилСуществует = Test-Path -Path $КаталогГруппыПравил
	if ( $КаталогГруппыПравилСуществует -eq $true ) {
		СобратьКоллекциюОбъектов -ИсходныйЭлемент $ИсходныйЭлемент -КаталогРодителя $КаталогГруппыПравил
	}
	
	$КаталогГруппыПравил = Join-Path -Path $КаталогРодителя -ChildPath "Правило"
	$КаталогГруппыПравилСуществует = Test-Path -Path $КаталогГруппыПравил
	if ( $КаталогГруппыПравилСуществует -eq $true ) {
		СобратьКоллекциюОбъектов -ИсходныйЭлемент $ИсходныйЭлемент -КаталогРодителя $КаталогГруппыПравил
	}
	
	$НайденныеФайлы = Get-ChildItem -Path $КаталогРодителя -Filter "*.xml"
	foreach ($Файл in $НайденныеФайлы) {
		
		$ДобавляемыйЭлемент = ПрочитатьЭлементИзФайла -ИмяФайла $Файл.FullName
		[void]$ИсходныйЭлемент.appendChild($ДобавляемыйЭлемент)
		
		$ДочерниеЭлементы = $ДобавляемыйЭлемент.selectNodes("*")
		foreach ($Элемент in $ДочерниеЭлементы) {
			
			$КаталогЭлемента = Join-Path -Path $КаталогРодителя -ChildPath (ДополнительныйКаталогЭлемента -Элемент $ДобавляемыйЭлемент)
			$КаталогКоллекции = КаталогКоллекции -ИсходныйКаталог $КаталогЭлемента -ИсходныйЭлемент $Элемент
			
			if ( ЭлементСодержитПрограммныйКод($Элемент) ) {
				ДобавитьПрограммныйКод -Элемент $Элемент -ИсходныйКаталог $КаталогКоллекции
			}
			
			if ( ЭлементЯвляетсяКоллекцией($Элемент) ) {
				СобратьКоллекциюОбъектов -ИсходныйЭлемент $Элемент -КаталогРодителя $КаталогКоллекции
			}
			
		}
		
		if ( ЭлементСодержитДочерниеКоллекции($ДобавляемыйЭлемент.nodeName) ) {
			$КаталогЭлемента = Join-Path -Path $КаталогРодителя -ChildPath (ДополнительныйКаталогЭлемента -Элемент $ДобавляемыйЭлемент)
			$КаталогКоллекции = КаталогКоллекции -ИсходныйКаталог $КаталогЭлемента -ИсходныйЭлемент $Элемент
			СобратьКоллекциюОбъектов -ИсходныйЭлемент $ДобавляемыйЭлемент -КаталогРодителя $КаталогКоллекции
		}
		
	}
	
}

function ДобавитьПрограммныйКод($Элемент, $ИсходныйКаталог) {
	
	$Файл = Join-Path -Path $ИсходныйКаталог -ChildPath "Ext\$($Элемент.nodeName).bsl"
	$СодержимоеФайла = Get-Content -Raw -Path $Файл
	
	if ( $null -ne $СодержимоеФайла ) {
		$Элемент.text = $СодержимоеФайла
	}
	
}

function ПрочитатьЭлементИзФайла($ИмяФайла) {

	$ЭлементыКоллекции = New-Object -ComObject MSXML2.DOMDocument.6.0
	$ЭлементыКоллекции.async = $false
	[void]$ЭлементыКоллекции.load($ИмяФайла)
	
	return $ЭлементыКоллекции.documentElement
	
}

function КаталогКоллекции($ИсходныйКаталог, $ИсходныйЭлемент) {

	if ( $ИсходныйЭлемент.nodeName -eq "Свойства" -or $ИсходныйЭлемент.nodeName -eq "Значения" `
		-or $ИсходныйЭлемент.nodeName -eq "Параметры" -or $ИсходныйЭлемент.nodeName -eq "Обработки" `
		-or $ИсходныйЭлемент.nodeName -eq "ПравилаКонвертацииОбъектов" `
		-or $ИсходныйЭлемент.nodeName -eq "ПравилаВыгрузкиДанных" `
		-or $ИсходныйЭлемент.nodeName -eq "ПравилаОчисткиДанных" `
		-or $ИсходныйЭлемент.nodeName -eq "Алгоритмы" -or $ИсходныйЭлемент.nodeName -eq "Запросы" ) {

		$КаталогКоллекции = Join-Path -Path $ИсходныйКаталог -ChildPath $ИсходныйЭлемент.nodeName
	}
	elseif ( $ИсходныйЭлемент.nodeName -eq "Алгоритм" `
		-or $ИсходныйЭлемент.nodeName -eq "Запрос" `
		-or $ИсходныйЭлемент.nodeName -eq "Параметр" ) {

		$ПутьКИмениЭлементаКоллекции = "@Имя"
		$КаталогКоллекции = Join-Path -Path $ИсходныйКаталог -ChildPath $ИсходныйЭлемент.SelectSingleNode($ПутьКИмениЭлементаКоллекции).text
	}	
	else {
		$КаталогКоллекции = $ИсходныйКаталог
		$ПутьКИмениЭлементаКоллекции = ""
	}
	
	return $КаталогКоллекции

}

function ДополнительныйКаталогЭлемента($Элемент) {
	
	$КаталогЭлемента = "";
	
	if ( $Элемент.nodeName -eq "Правило" -or $Элемент.nodeName -eq "Группа" ) {
		
		$КаталогЭлемента = $Элемент.SelectSingleNode("Код").text
	}
	elseif ( $Элемент.nodeName -eq "Алгоритм" -or $Элемент.nodeName -eq "Запрос" -or $Элемент.nodeName -eq "Параметр" ) {

		$КаталогЭлемента = $Элемент.SelectSingleNode("@Имя").text
	}
	elseif ( $Элемент.nodeName -eq "Свойство" -or $Элемент.nodeName -eq "Значение" ) {
		
		$КаталогЭлемента = $Элемент.SelectSingleNode("Код").text
	}
	
	return $КаталогЭлемента
		
}

function ЭлементСодержитПрограммныйКод($Элемент) {
	
	$СписокЭлементов = @{}
	
	# Обработчики Правил конвертации объектов
	$СписокЭлементов["ПередВыгрузкой"] = ""
	$СписокЭлементов["ПриВыгрузке"] = ""
	$СписокЭлементов["ПослеВыгрузки"] = ""
	$СписокЭлементов["ПослеВыгрузкиВФайл"] = ""
	$СписокЭлементов["ПоследовательностьПолейПоиска"] = ""		
	$СписокЭлементов["ПередЗагрузкой"] = ""
	$СписокЭлементов["ПриЗагрузке"] = ""
	$СписокЭлементов["ПослеЗагрузки"] = ""
	
	# Обработчики Правил выгрузки данных
	$СписокЭлементов["ПередОбработкойПравила"] = ""
	$СписокЭлементов["ПередВыгрузкойОбъекта"] = ""
	$СписокЭлементов["ПослеВыгрузкиОбъекта"] = ""
	$СписокЭлементов["ПослеОбработкиПравила"] = ""
	
	# Обработчики Правил очистки данных
	$СписокЭлементов["ПередОбработкойПравила"] = ""
	$СписокЭлементов["ПередУдалениемОбъекта"] = ""
	$СписокЭлементов["ПослеОбработкиПравила"] = ""
	
	# Текстовое поле алгоритма и запроса
	$СписокЭлементов["Текст"] = ""
	
	# Обработчики Конвертации
	$СписокЭлементов["ПослеЗагрузкиПравилОбмена"] = ""
	$СписокЭлементов["ПередВыгрузкойДанных"] = ""
	$СписокЭлементов["ПередПолучениемИзмененныхОбъектов"] = ""
	$СписокЭлементов["ПередВыгрузкойОбъекта"] = ""
	$СписокЭлементов["ПередОтправкойИнформацииОбУдалении"] = ""
	$СписокЭлементов["ПередКонвертациейОбъекта"] = ""
	$СписокЭлементов["ПослеВыгрузкиОбъекта"] = ""
	$СписокЭлементов["ПослеВыгрузкиДанных"] = ""
	$СписокЭлементов["ПередЗагрузкойДанных"] = ""
	$СписокЭлементов["ПослеЗагрузкиПараметров"] = ""
	$СписокЭлементов["ПослеПолученияИнформацииОбУзлахОбмена"] = ""
	$СписокЭлементов["ПередЗагрузкойОбъекта"] = ""
	$СписокЭлементов["ПриПолученииИнформацииОбУдалении"] = ""
	$СписокЭлементов["ПослеЗагрузкиОбъекта"] = ""
	$СписокЭлементов["ПослеЗагрузкиДанных"] = ""
	
	# Обработчики Параметров
	$СписокЭлементов["ПослеЗагрузкиПараметра"] = ""

	return $null -ne $СписокЭлементов[$Элемент.nodeName]
	
}

function ЭлементЯвляетсяКоллекцией($Элемент) {
	
	$СписокЭлементов = @{}
	
	# Имена элементов-коллекций конревых элементов: Ключ - имя элемента коллекции, Значение - допустимые имена родителельских элементов
	$СписокЭлементов["Параметры"] = "ПравилаОбмена"
	$СписокЭлементов["Обработки"] = ""
	$СписокЭлементов["ПравилаКонвертацииОбъектов"] = ""
	$СписокЭлементов["ПравилаВыгрузкиДанных"] = ""
	$СписокЭлементов["ПравилаОчисткиДанных"] = ""
	$СписокЭлементов["Алгоритмы"] = ""
	$СписокЭлементов["Запросы"] = ""

	# Имена элементов-коллекций внутри Правил
	$СписокЭлементов["Свойства"] = ""
	$СписокЭлементов["Значения"] = ""

	if ( $null -eq $СписокЭлементов[$Элемент.nodeName]) {
		return $false
	}
	elseif ( $СписокЭлементов[$Элемент.nodeName] -eq "" ) {
		return $true
	}
	elseif ( $СписокЭлементов[$Элемент.nodeName] -match $Элемент.parentNode.nodeName ) {
		return $true
	}
	
	return $false
	
}

function ЭлементСодержитДочерниеКоллекции($ИмяСвойства) {
	
	$СписокЭлементов = @{}

	# Имена элементов-коллекций внутри Правил
	$СписокЭлементов["Группа"] = ""
	
	return $null -ne $СписокЭлементов[$ИмяСвойства]
	
}


try {
	$ОбщийФайлПравил = New-Object -ComObject MSXML2.DOMDocument.6.0
	$ОбщийФайлПравил.async = $false
} catch {
	Write-Warning $_
	exit
}

$КаталогИсходныхКодов = Join-Path $PSScriptRoot "src"
$СобранныйФайл = Join-Path $PSScriptRoot "ПравилаОбмена_Собранные.xml"

Write-Host "Сборка файла правил обмена..."
СобратьКоллекциюОбъектов -ИсходныйЭлемент $ОбщийФайлПравил -КаталогРодителя $КаталогИсходныхКодов

$ОбщийФайлПравил.save($СобранныйФайл)