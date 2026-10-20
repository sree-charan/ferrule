// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

import Foundation

struct ConvertFeatureStrings {
    let title: String
    let hubDescription: String
    let panelCaption: String
    let dropPrompt: String
    let dropHint: String
    let addFinderSelection: String
    let chooseFiles: String
    let clear: String
    let removeFile: String
    let formatsTitle: String
    let filterPlaceholder: String
    let loadingFormats: String
    let noCommonFormat: String
    let outputLabel: String
    let outputNextToOriginals: String
    let outputChooseFolder: String
    let convertButton: String
    let converting: String
    let cancel: String
    /// Two numbers: files converted, files given.
    let resultFormat: String
    let reveal: String
    let recastMissingTitle: String
    let recastMissingMessage: String
    /// The path Recast runs from.
    let recastFoundFormat: String
    let commandTitle: String
    let commandSubtitle: String
    let settingsCaption: String
    let openWindow: String
}

extension FeatureStrings {
    static func convert(_ language: AppLanguage) -> ConvertFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension ConvertFeatureStrings {
    static let enUS = ConvertFeatureStrings(
        title: "Convert",
        hubDescription: "Convert images, documents, audio and video to other formats with Recast, entirely on this Mac",
        panelCaption: "Files to other formats",
        dropPrompt: "Drop files to convert",
        dropHint: "Or add the files selected in Finder.",
        addFinderSelection: "Add Finder Selection",
        chooseFiles: "Choose Files…",
        clear: "Clear",
        removeFile: "Remove",
        formatsTitle: "Convert to",
        filterPlaceholder: "Filter, e.g. docx",
        loadingFormats: "Reading formats…",
        noCommonFormat: "These files share no format. Convert them in smaller groups.",
        outputLabel: "Save to",
        outputNextToOriginals: "Next to the originals",
        outputChooseFolder: "Choose Folder…",
        convertButton: "Convert",
        converting: "Converting…",
        cancel: "Cancel",
        resultFormat: "Converted %d of %d",
        reveal: "Show in Finder",
        recastMissingTitle: "The converter is missing",
        recastMissingMessage: "This copy of Ferrule was built without its converter. Build it again with ./build.sh, which includes it.",
        recastFoundFormat: "Using Recast at %@",
        commandTitle: "Convert Files…",
        commandSubtitle: "Convert the Finder selection with Recast",
        settingsCaption: "Recast converts the files on this Mac and never uploads them.",
        openWindow: "Open Convert")

    static let ptBR = ConvertFeatureStrings(
        title: "Converter",
        hubDescription: "Converta imagens, documentos, áudio e vídeo para outros formatos com o Recast, tudo neste Mac",
        panelCaption: "Arquivos para outros formatos",
        dropPrompt: "Solte arquivos para converter",
        dropHint: "Ou adicione os arquivos selecionados no Finder.",
        addFinderSelection: "Adicionar seleção do Finder",
        chooseFiles: "Escolher arquivos…",
        clear: "Limpar",
        removeFile: "Remover",
        formatsTitle: "Converter para",
        filterPlaceholder: "Filtrar, ex. docx",
        loadingFormats: "Lendo formatos…",
        noCommonFormat: "Esses arquivos não têm formato em comum. Converta-os em grupos menores.",
        outputLabel: "Salvar em",
        outputNextToOriginals: "Junto aos originais",
        outputChooseFolder: "Escolher pasta…",
        convertButton: "Converter",
        converting: "Convertendo…",
        cancel: "Cancelar",
        resultFormat: "%d de %d convertidos",
        reveal: "Mostrar no Finder",
        recastMissingTitle: "O conversor não está presente",
        recastMissingMessage: "Esta cópia do Ferrule foi compilada sem o conversor. Compile-a de novo com ./build.sh, que o inclui.",
        recastFoundFormat: "Usando o Recast em %@",
        commandTitle: "Converter arquivos…",
        commandSubtitle: "Converter a seleção do Finder com o Recast",
        settingsCaption: "O Recast converte os arquivos neste Mac e nunca os envia.",
        openWindow: "Abrir Converter")

    static let tr = ConvertFeatureStrings(
        title: "Dönüştür",
        hubDescription: "Görüntüleri, belgeleri, sesi ve videoyu Recast ile tamamen bu Mac’te başka biçimlere dönüştürün",
        panelCaption: "Dosyaları başka biçimlere",
        dropPrompt: "Dönüştürmek için dosyaları bırakın",
        dropHint: "Ya da Finder’da seçili dosyaları ekleyin.",
        addFinderSelection: "Finder seçimini ekle",
        chooseFiles: "Dosya seç…",
        clear: "Temizle",
        removeFile: "Kaldır",
        formatsTitle: "Hedef biçim",
        filterPlaceholder: "Süz, ör. docx",
        loadingFormats: "Biçimler okunuyor…",
        noCommonFormat: "Bu dosyaların ortak bir biçimi yok. Daha küçük gruplar halinde dönüştürün.",
        outputLabel: "Kaydetme yeri",
        outputNextToOriginals: "Orijinallerin yanına",
        outputChooseFolder: "Klasör seç…",
        convertButton: "Dönüştür",
        converting: "Dönüştürülüyor…",
        cancel: "Vazgeç",
        resultFormat: "%d / %d dönüştürüldü",
        reveal: "Finder’da göster",
        recastMissingTitle: "Dönüştürücü eksik",
        recastMissingMessage: "Ferrule’ün bu kopyası dönüştürücüsü olmadan derlendi. Onu da içeren ./build.sh ile yeniden derleyin.",
        recastFoundFormat: "Kullanılan Recast: %@",
        commandTitle: "Dosyaları dönüştür…",
        commandSubtitle: "Finder seçimini Recast ile dönüştür",
        settingsCaption: "Recast dosyaları bu Mac’te dönüştürür ve hiçbir zaman yüklemez.",
        openWindow: "Dönüştür’ü aç")

    static let ru = ConvertFeatureStrings(
        title: "Конвертер",
        hubDescription: "Преобразуйте изображения, документы, аудио и видео в другие форматы с помощью Recast прямо на этом Mac",
        panelCaption: "Файлы в другие форматы",
        dropPrompt: "Перетащите файлы для преобразования",
        dropHint: "Или добавьте файлы, выбранные в Finder.",
        addFinderSelection: "Добавить выбранное в Finder",
        chooseFiles: "Выбрать файлы…",
        clear: "Очистить",
        removeFile: "Убрать",
        formatsTitle: "Преобразовать в",
        filterPlaceholder: "Фильтр, напр. docx",
        loadingFormats: "Чтение форматов…",
        noCommonFormat: "У этих файлов нет общего формата. Преобразуйте их меньшими группами.",
        outputLabel: "Сохранить",
        outputNextToOriginals: "Рядом с оригиналами",
        outputChooseFolder: "Выбрать папку…",
        convertButton: "Преобразовать",
        converting: "Преобразование…",
        cancel: "Отменить",
        resultFormat: "Преобразовано %d из %d",
        reveal: "Показать в Finder",
        recastMissingTitle: "Конвертер отсутствует",
        recastMissingMessage: "Эта копия Ferrule собрана без конвертера. Соберите её заново через ./build.sh, он его добавляет.",
        recastFoundFormat: "Используется Recast: %@",
        commandTitle: "Преобразовать файлы…",
        commandSubtitle: "Преобразовать выбранное в Finder с помощью Recast",
        settingsCaption: "Recast преобразует файлы на этом Mac и никуда их не отправляет.",
        openWindow: "Открыть конвертер")

    static let es = ConvertFeatureStrings(
        title: "Convertir",
        hubDescription: "Convierte imágenes, documentos, audio y vídeo a otros formatos con Recast, todo en este Mac",
        panelCaption: "Archivos a otros formatos",
        dropPrompt: "Suelta archivos para convertir",
        dropHint: "O añade los archivos seleccionados en el Finder.",
        addFinderSelection: "Añadir selección del Finder",
        chooseFiles: "Elegir archivos…",
        clear: "Vaciar",
        removeFile: "Quitar",
        formatsTitle: "Convertir a",
        filterPlaceholder: "Filtrar, p. ej. docx",
        loadingFormats: "Leyendo formatos…",
        noCommonFormat: "Estos archivos no tienen ningún formato en común. Conviértelos en grupos más pequeños.",
        outputLabel: "Guardar en",
        outputNextToOriginals: "Junto a los originales",
        outputChooseFolder: "Elegir carpeta…",
        convertButton: "Convertir",
        converting: "Convirtiendo…",
        cancel: "Cancelar",
        resultFormat: "%d de %d convertidos",
        reveal: "Mostrar en el Finder",
        recastMissingTitle: "Falta el conversor",
        recastMissingMessage: "Esta copia de Ferrule se compiló sin su conversor. Vuelve a compilarla con ./build.sh, que lo incluye.",
        recastFoundFormat: "Usando Recast en %@",
        commandTitle: "Convertir archivos…",
        commandSubtitle: "Convertir la selección del Finder con Recast",
        settingsCaption: "Recast convierte los archivos en este Mac y nunca los sube.",
        openWindow: "Abrir Convertir")

    static let sk = ConvertFeatureStrings(
        title: "Konvertovať",
        hubDescription: "Konvertujte obrázky, dokumenty, zvuk a video do iných formátov pomocou Recastu, priamo na tomto Macu",
        panelCaption: "Súbory do iných formátov",
        dropPrompt: "Pustite súbory na konverziu",
        dropHint: "Alebo pridajte súbory vybraté vo Finderi.",
        addFinderSelection: "Pridať výber z Findera",
        chooseFiles: "Vybrať súbory…",
        clear: "Vymazať",
        removeFile: "Odstrániť",
        formatsTitle: "Konvertovať na",
        filterPlaceholder: "Filtrovať, napr. docx",
        loadingFormats: "Načítavajú sa formáty…",
        noCommonFormat: "Tieto súbory nemajú spoločný formát. Konvertujte ich v menších skupinách.",
        outputLabel: "Uložiť do",
        outputNextToOriginals: "Vedľa originálov",
        outputChooseFolder: "Vybrať priečinok…",
        convertButton: "Konvertovať",
        converting: "Konvertuje sa…",
        cancel: "Zrušiť",
        resultFormat: "Konvertované: %d z %d",
        reveal: "Zobraziť vo Finderi",
        recastMissingTitle: "Chýba konvertor",
        recastMissingMessage: "Táto kópia Ferrule bola zostavená bez konvertora. Zostavte ju znova pomocou ./build.sh, ktorý ho pridá.",
        recastFoundFormat: "Používa sa Recast v %@",
        commandTitle: "Konvertovať súbory…",
        commandSubtitle: "Konvertovať výber z Findera pomocou Recastu",
        settingsCaption: "Recast konvertuje súbory na tomto Macu a nikdy ich neodosiela.",
        openWindow: "Otvoriť Konvertovať")

    static let de = ConvertFeatureStrings(
        title: "Konvertieren",
        hubDescription: "Bilder, Dokumente, Audio und Video mit Recast in andere Formate umwandeln, vollständig auf diesem Mac",
        panelCaption: "Dateien in andere Formate",
        dropPrompt: "Dateien zum Konvertieren hier ablegen",
        dropHint: "Oder die im Finder ausgewählten Dateien hinzufügen.",
        addFinderSelection: "Finder-Auswahl hinzufügen",
        chooseFiles: "Dateien auswählen …",
        clear: "Leeren",
        removeFile: "Entfernen",
        formatsTitle: "Konvertieren in",
        filterPlaceholder: "Filtern, z. B. docx",
        loadingFormats: "Formate werden gelesen …",
        noCommonFormat: "Diese Dateien haben kein gemeinsames Format. Konvertiere sie in kleineren Gruppen.",
        outputLabel: "Speichern in",
        outputNextToOriginals: "Neben den Originalen",
        outputChooseFolder: "Ordner auswählen …",
        convertButton: "Konvertieren",
        converting: "Wird konvertiert …",
        cancel: "Abbrechen",
        resultFormat: "%d von %d konvertiert",
        reveal: "Im Finder zeigen",
        recastMissingTitle: "Der Konverter fehlt",
        recastMissingMessage: "Diese Kopie von Ferrule wurde ohne ihren Konverter gebaut. Baue sie mit ./build.sh neu, das ihn mitbringt.",
        recastFoundFormat: "Recast unter %@",
        commandTitle: "Dateien konvertieren …",
        commandSubtitle: "Die Finder-Auswahl mit Recast konvertieren",
        settingsCaption: "Recast konvertiert die Dateien auf diesem Mac und lädt sie nie hoch.",
        openWindow: "Konvertieren öffnen")

    static let fr = ConvertFeatureStrings(
        title: "Convertir",
        hubDescription: "Convertissez images, documents, audio et vidéo vers d’autres formats avec Recast, entièrement sur ce Mac",
        panelCaption: "Fichiers vers d’autres formats",
        dropPrompt: "Déposez des fichiers à convertir",
        dropHint: "Ou ajoutez les fichiers sélectionnés dans le Finder.",
        addFinderSelection: "Ajouter la sélection du Finder",
        chooseFiles: "Choisir des fichiers…",
        clear: "Vider",
        removeFile: "Retirer",
        formatsTitle: "Convertir en",
        filterPlaceholder: "Filtrer, p. ex. docx",
        loadingFormats: "Lecture des formats…",
        noCommonFormat: "Ces fichiers n’ont aucun format en commun. Convertissez-les par plus petits groupes.",
        outputLabel: "Enregistrer dans",
        outputNextToOriginals: "À côté des originaux",
        outputChooseFolder: "Choisir un dossier…",
        convertButton: "Convertir",
        converting: "Conversion…",
        cancel: "Annuler",
        resultFormat: "%d sur %d convertis",
        reveal: "Afficher dans le Finder",
        recastMissingTitle: "Le convertisseur est absent",
        recastMissingMessage: "Cette copie de Ferrule a été compilée sans son convertisseur. Recompilez-la avec ./build.sh, qui l’inclut.",
        recastFoundFormat: "Recast utilisé : %@",
        commandTitle: "Convertir des fichiers…",
        commandSubtitle: "Convertir la sélection du Finder avec Recast",
        settingsCaption: "Recast convertit les fichiers sur ce Mac et ne les envoie jamais.",
        openWindow: "Ouvrir Convertir")

    static let it = ConvertFeatureStrings(
        title: "Converti",
        hubDescription: "Converti immagini, documenti, audio e video in altri formati con Recast, interamente su questo Mac",
        panelCaption: "File in altri formati",
        dropPrompt: "Trascina qui i file da convertire",
        dropHint: "Oppure aggiungi i file selezionati nel Finder.",
        addFinderSelection: "Aggiungi selezione del Finder",
        chooseFiles: "Scegli file…",
        clear: "Svuota",
        removeFile: "Rimuovi",
        formatsTitle: "Converti in",
        filterPlaceholder: "Filtra, es. docx",
        loadingFormats: "Lettura dei formati…",
        noCommonFormat: "Questi file non hanno formati in comune. Convertili in gruppi più piccoli.",
        outputLabel: "Salva in",
        outputNextToOriginals: "Accanto agli originali",
        outputChooseFolder: "Scegli cartella…",
        convertButton: "Converti",
        converting: "Conversione…",
        cancel: "Annulla",
        resultFormat: "%d di %d convertiti",
        reveal: "Mostra nel Finder",
        recastMissingTitle: "Manca il convertitore",
        recastMissingMessage: "Questa copia di Ferrule è stata compilata senza il convertitore. Ricompilala con ./build.sh, che lo include.",
        recastFoundFormat: "Recast in uso: %@",
        commandTitle: "Converti file…",
        commandSubtitle: "Converti la selezione del Finder con Recast",
        settingsCaption: "Recast converte i file su questo Mac e non li carica mai.",
        openWindow: "Apri Converti")

    static let ja = ConvertFeatureStrings(
        title: "変換",
        hubDescription: "画像、書類、オーディオ、ビデオを Recast でほかの形式に変換します。すべてこの Mac 上で行います",
        panelCaption: "ファイルをほかの形式に",
        dropPrompt: "変換するファイルをドロップ",
        dropHint: "または Finder で選択中のファイルを追加します。",
        addFinderSelection: "Finder の選択項目を追加",
        chooseFiles: "ファイルを選択…",
        clear: "消去",
        removeFile: "取り除く",
        formatsTitle: "変換先",
        filterPlaceholder: "絞り込み（例: docx）",
        loadingFormats: "形式を読み込み中…",
        noCommonFormat: "これらのファイルに共通の形式はありません。小さなグループに分けて変換してください。",
        outputLabel: "保存先",
        outputNextToOriginals: "元のファイルと同じ場所",
        outputChooseFolder: "フォルダを選択…",
        convertButton: "変換",
        converting: "変換中…",
        cancel: "キャンセル",
        resultFormat: "%d / %d 件を変換しました",
        reveal: "Finder で表示",
        recastMissingTitle: "変換エンジンがありません",
        recastMissingMessage: "この Ferrule は変換エンジンなしでビルドされています。変換エンジンを含める ./build.sh でビルドし直してください。",
        recastFoundFormat: "使用中の Recast: %@",
        commandTitle: "ファイルを変換…",
        commandSubtitle: "Finder の選択項目を Recast で変換",
        settingsCaption: "Recast はこの Mac 上でファイルを変換し、アップロードすることはありません。",
        openWindow: "変換を開く")

    static let ko = ConvertFeatureStrings(
        title: "변환",
        hubDescription: "Recast로 이미지, 문서, 오디오, 비디오를 다른 형식으로 변환합니다. 모든 작업은 이 Mac에서 이루어집니다",
        panelCaption: "파일을 다른 형식으로",
        dropPrompt: "변환할 파일을 놓으세요",
        dropHint: "또는 Finder에서 선택한 파일을 추가하세요.",
        addFinderSelection: "Finder 선택 항목 추가",
        chooseFiles: "파일 선택…",
        clear: "비우기",
        removeFile: "제거",
        formatsTitle: "변환할 형식",
        filterPlaceholder: "필터 (예: docx)",
        loadingFormats: "형식을 읽는 중…",
        noCommonFormat: "이 파일들에는 공통 형식이 없습니다. 더 작은 묶음으로 나눠 변환하세요.",
        outputLabel: "저장 위치",
        outputNextToOriginals: "원본 옆",
        outputChooseFolder: "폴더 선택…",
        convertButton: "변환",
        converting: "변환 중…",
        cancel: "취소",
        resultFormat: "%d/%d개 변환됨",
        reveal: "Finder에서 보기",
        recastMissingTitle: "변환 엔진이 없습니다",
        recastMissingMessage: "이 Ferrule은 변환 엔진 없이 빌드되었습니다. 변환 엔진을 포함하는 ./build.sh로 다시 빌드하세요.",
        recastFoundFormat: "사용 중인 Recast: %@",
        commandTitle: "파일 변환…",
        commandSubtitle: "Finder 선택 항목을 Recast로 변환",
        settingsCaption: "Recast는 이 Mac에서 파일을 변환하며 업로드하지 않습니다.",
        openWindow: "변환 열기")

    static let uk = ConvertFeatureStrings(
        title: "Конвертер",
        hubDescription: "Перетворюйте зображення, документи, аудіо й відео на інші формати за допомогою Recast просто на цьому Mac",
        panelCaption: "Файли в інші формати",
        dropPrompt: "Перетягніть файли для перетворення",
        dropHint: "Або додайте файли, вибрані у Finder.",
        addFinderSelection: "Додати вибране у Finder",
        chooseFiles: "Вибрати файли…",
        clear: "Очистити",
        removeFile: "Прибрати",
        formatsTitle: "Перетворити на",
        filterPlaceholder: "Фільтр, напр. docx",
        loadingFormats: "Зчитування форматів…",
        noCommonFormat: "Ці файли не мають спільного формату. Перетворюйте їх меншими групами.",
        outputLabel: "Зберегти",
        outputNextToOriginals: "Поруч з оригіналами",
        outputChooseFolder: "Вибрати папку…",
        convertButton: "Перетворити",
        converting: "Перетворення…",
        cancel: "Скасувати",
        resultFormat: "Перетворено %d з %d",
        reveal: "Показати у Finder",
        recastMissingTitle: "Конвертер відсутній",
        recastMissingMessage: "Цю копію Ferrule зібрано без конвертера. Зберіть її знову через ./build.sh, він його додає.",
        recastFoundFormat: "Використовується Recast: %@",
        commandTitle: "Перетворити файли…",
        commandSubtitle: "Перетворити вибране у Finder за допомогою Recast",
        settingsCaption: "Recast перетворює файли на цьому Mac і нікуди їх не надсилає.",
        openWindow: "Відкрити конвертер")

    static let zhHans = ConvertFeatureStrings(
        title: "转换",
        hubDescription: "用 Recast 将图像、文稿、音频和视频转换为其他格式，全程在这台 Mac 上完成",
        panelCaption: "将文件转为其他格式",
        dropPrompt: "将要转换的文件拖到这里",
        dropHint: "或添加在“访达”中选中的文件。",
        addFinderSelection: "添加“访达”选中项",
        chooseFiles: "选择文件…",
        clear: "清空",
        removeFile: "移除",
        formatsTitle: "转换为",
        filterPlaceholder: "筛选，例如 docx",
        loadingFormats: "正在读取格式…",
        noCommonFormat: "这些文件没有共同的格式。请分成更小的组来转换。",
        outputLabel: "存储到",
        outputNextToOriginals: "原文件旁边",
        outputChooseFolder: "选择文件夹…",
        convertButton: "转换",
        converting: "正在转换…",
        cancel: "取消",
        resultFormat: "已转换 %d 个，共 %d 个",
        reveal: "在“访达”中显示",
        recastMissingTitle: "缺少转换引擎",
        recastMissingMessage: "这份 Ferrule 构建时没有包含转换引擎。请用会一并包含它的 ./build.sh 重新构建。",
        recastFoundFormat: "正在使用的 Recast：%@",
        commandTitle: "转换文件…",
        commandSubtitle: "用 Recast 转换“访达”中的选中项",
        settingsCaption: "Recast 在这台 Mac 上转换文件，从不上传。",
        openWindow: "打开转换")

    static let zhTW = ConvertFeatureStrings(
        title: "轉換",
        hubDescription: "用 Recast 將影像、文件、音訊和影片轉換成其他格式，全程在這台 Mac 上完成",
        panelCaption: "將檔案轉成其他格式",
        dropPrompt: "將要轉換的檔案拖到這裡",
        dropHint: "或加入在 Finder 中選取的檔案。",
        addFinderSelection: "加入 Finder 選取項目",
        chooseFiles: "選擇檔案⋯",
        clear: "清除",
        removeFile: "移除",
        formatsTitle: "轉換為",
        filterPlaceholder: "篩選，例如 docx",
        loadingFormats: "正在讀取格式⋯",
        noCommonFormat: "這些檔案沒有共同的格式。請分成較小的群組來轉換。",
        outputLabel: "儲存到",
        outputNextToOriginals: "原始檔案旁邊",
        outputChooseFolder: "選擇資料夾⋯",
        convertButton: "轉換",
        converting: "正在轉換⋯",
        cancel: "取消",
        resultFormat: "已轉換 %d 個，共 %d 個",
        reveal: "在 Finder 中顯示",
        recastMissingTitle: "缺少轉換引擎",
        recastMissingMessage: "這份 Ferrule 建置時沒有包含轉換引擎。請用會一併包含它的 ./build.sh 重新建置。",
        recastFoundFormat: "使用中的 Recast：%@",
        commandTitle: "轉換檔案⋯",
        commandSubtitle: "用 Recast 轉換 Finder 選取項目",
        settingsCaption: "Recast 在這台 Mac 上轉換檔案，絕不上傳。",
        openWindow: "打開轉換")

    static let zhHK = ConvertFeatureStrings(
        title: "轉換",
        hubDescription: "用 Recast 將影像、文件、音訊和影片轉換成其他格式，全程在這部 Mac 上完成",
        panelCaption: "將檔案轉成其他格式",
        dropPrompt: "將要轉換的檔案拖到這裡",
        dropHint: "或加入在 Finder 中選取的檔案。",
        addFinderSelection: "加入 Finder 選取項目",
        chooseFiles: "選擇檔案⋯",
        clear: "清除",
        removeFile: "移除",
        formatsTitle: "轉換為",
        filterPlaceholder: "篩選，例如 docx",
        loadingFormats: "正在讀取格式⋯",
        noCommonFormat: "這些檔案沒有共同的格式。請分成較小的組別來轉換。",
        outputLabel: "儲存到",
        outputNextToOriginals: "原始檔案旁邊",
        outputChooseFolder: "選擇資料夾⋯",
        convertButton: "轉換",
        converting: "正在轉換⋯",
        cancel: "取消",
        resultFormat: "已轉換 %d 個，共 %d 個",
        reveal: "在 Finder 中顯示",
        recastMissingTitle: "缺少轉換引擎",
        recastMissingMessage: "這份 Ferrule 建置時沒有包含轉換引擎。請用會一併包含它的 ./build.sh 重新建置。",
        recastFoundFormat: "使用中的 Recast：%@",
        commandTitle: "轉換檔案⋯",
        commandSubtitle: "用 Recast 轉換 Finder 選取項目",
        settingsCaption: "Recast 在這部 Mac 上轉換檔案，絕不上載。",
        openWindow: "打開轉換")
}
