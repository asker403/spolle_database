//
//  LanguageManager.swift
//  Spolle
//
//  Created by Kiro on 7/23/25.
//

import SwiftUI
import Foundation

// MARK: - Language Manager
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.code, forKey: "selectedLanguage")
            UserDefaults.standard.synchronize()
        }
    }
    
    private init() {
        let savedLanguageCode = UserDefaults.standard.string(forKey: "selectedLanguage")
        self.currentLanguage = Language.allCases.first { $0.code == savedLanguageCode } ?? .english
    }
    
    func localizedString(for key: String) -> String {
        return LocalizedStrings.getString(key: key, language: currentLanguage)
    }
}

// MARK: - Language Enum
enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case turkish = "Türkçe"
    case german = "Deutsch"
    case french = "Français"
    case spanish = "Español"
    case portuguese = "Português"
    case russian = "Русский"
    case ukrainian = "Українська"
    case chineseSimplified = "中文 (简体)"
    case japanese = "日本語"
    
    var id: String { rawValue }
    
    var code: String {
        switch self {
        case .english: return "🇺🇸"
        case .turkish: return "🇹🇷"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "es"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .ukrainian: return "uk"
        case .chineseSimplified: return "zh-Hans"
        case .japanese: return "ja"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .turkish: return "🇹🇷"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇵🇹"
        case .russian: return "🇷🇺"
        case .ukrainian: return "🇺🇦"
        case .chineseSimplified: return "🇨🇳"
        case .japanese: return "🇯🇵"
        }
    }
}

// MARK: - Localized Strings
struct LocalizedStrings {
    static func getString(key: String, language: Language) -> String {
        switch language {
        case .english:
            return englishStrings[key] ?? key
        case .turkish:
            return turkishStrings[key] ?? key
        case .german:
            return germanStrings[key] ?? key
        case .french:
            return frenchStrings[key] ?? key
        case .spanish:
            return spanishStrings[key] ?? key
        case .portuguese:
            return portugueseStrings[key] ?? key
        case .russian:
            return russianStrings[key] ?? key
        case .ukrainian:
            return ukrainianStrings[key] ?? key
        case .chineseSimplified:
            return chineseSimplifiedStrings[key] ?? key
        case .japanese:
            return japaneseStrings[key] ?? key
        }
    }
    
    // MARK: - English Strings
    private static let englishStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Daily Guess",
        "guess_the_artist": "Guess the Artist",
        "challenge_yourself": "Challenge yourself with a new artist.",
        "start_the_game": "Start the Game",
        
        // Game View
        "enter_your_guess": "Enter your guess",
        "submit_guess": "Submit Guess",
        "remaining_guesses": "Remaining Guesses",
        "your_guesses": "Your Guesses",
        "correct": "🟢 Correct",
        "close_match": "🟡 Close",
        "wrong": "⚪ Wrong",
        "latest_guess_first": "Latest guess shown first",
        "latest": "LATEST",
        
        // Game Results
        "correct_celebration": "🎉 Correct!",
        "game_over": "Game Over!",
        "you_guessed": "You guessed %@!",
        "answer_was": "The answer was: %@",
        "view_result": "View Result",
        
        // Success View
        "congratulations": "Congratulations!",
        "you_got_it": "You got it right!",
        "better_luck": "Better luck next time!",
        "the_artist_was": "The artist was",
        "play_again": "Play Again",
        "share_result": "Share Result",
        "back_to_menu": "Back to Menu",
        
        // Settings
        "settings": "Settings",
        "language": "Language",
        "select_language": "Select Language",
        "theme": "Theme",
        "dark_mode": "Dark Mode",
        "light_mode": "Light Mode",
        
        // Help
        "help": "Help",
        "how_to_play": "How to Play",
        "game_rules": "Game Rules",
        "close": "Close",
        
        // Help Content
        "objective": "Objective",
        "objective_description": "Guess the daily featured artist in 10 attempts or less.",
        "hints": "Hints",
        "hints_description": "After each guess, you'll receive hints about the artist including their gender, country, debut year, genre, whether they're solo or in a group, and their Spotify popularity ranking.",
        "color_coding": "Color Coding",
        "color_coding_description": "🟢 Green: Correct information\n🟡 Yellow: Close but not exact\n⚪ Gray: Incorrect information",
        "daily_challenge": "Daily Challenge",
        "daily_challenge_description": "A new artist is featured every day. Come back tomorrow for a new challenge!",
        
        // Hints
        "popularity": "Popularity",
        "followers": "Followers",
        "genres": "Genres",
        "country": "Country",
        "debut_year": "Debut Year",
        "albums": "Albums",
        
        // Hint Card Titles
        "Genre": "Genre",
        "Country": "Country", 
        "Debut Year": "Debut Year",
        "Gender": "Gender",
        "Type": "Type",
        "Popularity": "Popularity",
        
        // Common
        "cancel": "Cancel",
        "done": "Done",
        "ok": "OK",
        "yes": "Yes",
        "no": "No",
        "new_game": "New Game",
        
        // Additional strings
        "play_preview": "Play Preview",
        "pause_preview": "Pause Preview",
        "no_image": "No Image",
        
        // Rating
        "enjoying_spolle": "Enjoying Spolle?",
        "rate_us_description": "If you love playing our daily artist guessing game, please take a moment to rate us on the App Store!",
        "rate_spolle": "Rate Spolle",
        "maybe_later": "Maybe Later",
        
        // Game Screen
        "guess_daily_artist_spotify": "Guess the daily artist from Spotify",
        "genre_label": "Genre",
        "country_label": "Country",
        "debut_year_label": "Debut Year",
        



    ]
    
    // MARK: - Turkish Strings
    private static let turkishStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Günlük Tahmin",
        "guess_the_artist": "Sanatçıyı Tahmin Et",
        "challenge_yourself": "Yeni bir sanatçıyla kendini test et.",
        "start_the_game": "Oyunu Başlat",
        
        // Game View
        "enter_your_guess": "Tahmininizi girin",
        "submit_guess": "Tahmini Gönder",
        "remaining_guesses": "Kalan Tahmin",
        "your_guesses": "Tahminleriniz",
        "correct": "🟢 Doğru",
        "close_match": "🟡 Yakın",
        "wrong": "⚪ Yanlış",
        "latest_guess_first": "En son tahmin önce gösteriliyor",
        "latest": "SON",
        
        // Game Results
        "correct_celebration": "🎉 Doğru!",
        "game_over": "Oyun Bitti!",
        "you_guessed": "%@'i tahmin ettiniz!",
        "answer_was": "Cevap şuydu: %@",
        "view_result": "Sonucu Gör",
        
        // Success View
        "congratulations": "Tebrikler!",
        "you_got_it": "Doğru bildiniz!",
        "better_luck": "Bir dahaki sefere!",
        "the_artist_was": "Sanatçı şuydu",
        "play_again": "Tekrar Oyna",
        "share_result": "Sonucu Paylaş",
        "back_to_menu": "Ana Menüye Dön",
        
        // Settings
        "settings": "Ayarlar",
        "language": "Dil",
        "select_language": "Dil Seçin",
        "theme": "Tema",
        "dark_mode": "Karanlık Mod",
        "light_mode": "Açık Mod",
        
        // Help
        "help": "Yardım",
        "how_to_play": "Nasıl Oynanır",
        "game_rules": "Oyun Kuralları",
        "close": "Kapat",
        
        // Help Content
        "objective": "Amaç",
        "objective_description": "Günlük öne çıkan sanatçıyı 10 denemede veya daha azında tahmin edin.",
        "hints": "İpuçları",
        "hints_description": "Her tahmininizden sonra sanatçı hakkında cinsiyet, ülke, çıkış yılı, tür, solo mu grup mu olduğu ve Spotify popülerlik sıralaması gibi ipuçları alacaksınız.",
        "color_coding": "Renk Kodlaması",
        "color_coding_description": "🟢 Yeşil: Doğru bilgi\n🟡 Sarı: Yakın ama tam değil\n⚪ Gri: Yanlış bilgi",
        "daily_challenge": "Günlük Meydan Okuma",
        "daily_challenge_description": "Her gün yeni bir sanatçı öne çıkarılır. Yeni bir meydan okuma için yarın tekrar gelin!",
        
        // Hints
        "popularity": "Popülerlik",
        "followers": "Takipçiler",
        "genres": "Türler",
        "country": "Ülke",
        "debut_year": "Çıkış Yılı",
        "albums": "Albümler",
        
        // Hint Card Titles
        "Genre": "Tür",
        "Country": "Ülke",
        "Debut Year": "Çıkış Yılı",
        "Gender": "Cinsiyet",
        "Type": "Tip",
        "Popularity": "Popülerlik",
        
        // Common
        "cancel": "İptal",
        "done": "Bitti",
        "ok": "Tamam",
        "yes": "Evet",
        "no": "Hayır",
        "new_game": "Yeni Oyun",
        
        // Additional strings
        "play_preview": "Önizlemeyi Oynat",
        "pause_preview": "Önizlemeyi Duraklat",
        "no_image": "Resim Yok",
        
        // Rating
        "enjoying_spolle": "Spolle'yi Beğeniyor musunuz?",
        "rate_us_description": "Günlük sanatçı tahmin oyunumuzu seviyorsanız, lütfen App Store'da bizi değerlendirmek için bir dakikanızı ayırın!",
        "rate_spolle": "Spolle'yi Değerlendir",
        "maybe_later": "Belki Sonra",
        
        // Game Screen
        "guess_daily_artist_spotify": "Spotify'dan günlük sanatçıyı tahmin edin",
        "genre_label": "Tür",
        "country_label": "Ülke",
        "debut_year_label": "Çıkış Yılı",
        



    ]
    
    // MARK: - German Strings
    private static let germanStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Tägliches Raten",
        "guess_the_artist": "Rate den Künstler",
        "challenge_yourself": "Fordere dich mit einem neuen Künstler heraus.",
        "start_the_game": "Spiel Starten",
        
        // Game View
        "enter_your_guess": "Gib deine Vermutung ein",
        "submit_guess": "Vermutung Abgeben",
        "remaining_guesses": "Verbleibende Versuche",
        "your_guesses": "Deine Vermutungen",
        "correct": "🟢 Richtig",
        "close_match": "🟡 Nah",
        "wrong": "⚪ Falsch",
        "latest_guess_first": "Neueste Vermutung zuerst angezeigt",
        "latest": "NEUESTE",
        
        // Game Results
        "correct_celebration": "🎉 Richtig!",
        "game_over": "Spiel Vorbei!",
        "you_guessed": "Du hast %@ erraten!",
        "answer_was": "Die Antwort war: %@",
        "view_result": "Ergebnis Anzeigen",
        
        // Success View
        "congratulations": "Glückwunsch!",
        "you_got_it": "Du hast es richtig gemacht!",
        "better_luck": "Viel Glück beim nächsten Mal!",
        "the_artist_was": "Der Künstler war",
        "play_again": "Nochmal Spielen",
        "share_result": "Ergebnis Teilen",
        "back_to_menu": "Zurück zum Menü",
        
        // Settings
        "settings": "Einstellungen",
        "language": "Sprache",
        "select_language": "Sprache Auswählen",
        "theme": "Design",
        "dark_mode": "Dunkler Modus",
        "light_mode": "Heller Modus",
        
        // Help
        "help": "Hilfe",
        "how_to_play": "Wie zu Spielen",
        "game_rules": "Spielregeln",
        "close": "Schließen",
        
        // Help Content
        "objective": "Ziel",
        "objective_description": "Erraten Sie den täglich vorgestellten Künstler in 10 Versuchen oder weniger.",
        "hints": "Hinweise",
        "hints_description": "Nach jeder Vermutung erhalten Sie Hinweise über den Künstler, einschließlich Geschlecht, Land, Debütjahr, Genre, ob sie solo oder in einer Gruppe sind, und ihre Spotify-Popularitätsbewertung.",
        "color_coding": "Farbkodierung",
        "color_coding_description": "🟢 Grün: Richtige Information\n🟡 Gelb: Nah, aber nicht genau\n⚪ Grau: Falsche Information",
        "daily_challenge": "Tägliche Herausforderung",
        "daily_challenge_description": "Jeden Tag wird ein neuer Künstler vorgestellt. Kommen Sie morgen für eine neue Herausforderung zurück!",
        
        // Hints
        "popularity": "Beliebtheit",
        "followers": "Follower",
        "genres": "Genres",
        "country": "Land",
        "debut_year": "Debütjahr",
        "albums": "Alben",
        
        // Hint Card Titles
        "Genre": "Genre",
        "Country": "Land",
        "Debut Year": "Debütjahr",
        "Gender": "Geschlecht",
        "Type": "Typ",
        "Popularity": "Beliebtheit",
        
        // Common
        "cancel": "Abbrechen",
        "done": "Fertig",
        "ok": "OK",
        "yes": "Ja",
        "no": "Nein",
        "new_game": "Neues Spiel",
        
        // Additional strings
        "play_preview": "Vorschau Abspielen",
        "pause_preview": "Vorschau Pausieren",
        "no_image": "Kein Bild",
        
        // Rating
        "enjoying_spolle": "Gefällt Ihnen Spolle?",
        "rate_us_description": "Wenn Sie unser tägliches Künstler-Ratespiel lieben, nehmen Sie sich bitte einen Moment Zeit, um uns im App Store zu bewerten!",
        "rate_spolle": "Spolle Bewerten",
        "maybe_later": "Vielleicht Später",
        
        // Game Screen
        "guess_daily_artist_spotify": "Erraten Sie den täglichen Künstler von Spotify",
        "genre_label": "Genre",
        "country_label": "Land",
        "debut_year_label": "Debütjahr",
        



    ]
    
    // MARK: - French Strings
    private static let frenchStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Devinette Quotidienne",
        "guess_the_artist": "Devinez l'Artiste",
        "challenge_yourself": "Défiez-vous avec un nouvel artiste.",
        "start_the_game": "Commencer le Jeu",
        
        // Game View
        "enter_your_guess": "Entrez votre supposition",
        "submit_guess": "Soumettre la Supposition",
        "remaining_guesses": "Tentatives Restantes",
        "your_guesses": "Vos Suppositions",
        "correct": "🟢 Correct",
        "close_match": "🟡 Proche",
        "wrong": "⚪ Faux",
        "latest_guess_first": "Dernière supposition affichée en premier",
        "latest": "DERNIER",
        
        // Game Results
        "correct_celebration": "🎉 Correct!",
        "game_over": "Jeu Terminé!",
        "you_guessed": "Vous avez deviné %@!",
        "answer_was": "La réponse était: %@",
        "view_result": "Voir le Résultat",
        
        // Success View
        "congratulations": "Félicitations!",
        "you_got_it": "Vous avez trouvé!",
        "better_luck": "Bonne chance la prochaine fois!",
        "the_artist_was": "L'artiste était",
        "play_again": "Rejouer",
        "share_result": "Partager le Résultat",
        "back_to_menu": "Retour au Menu",
        
        // Settings
        "settings": "Paramètres",
        "language": "Langue",
        "select_language": "Sélectionner la Langue",
        "theme": "Thème",
        "dark_mode": "Mode Sombre",
        "light_mode": "Mode Clair",
        
        // Help
        "help": "Aide",
        "how_to_play": "Comment Jouer",
        "game_rules": "Règles du Jeu",
        "close": "Fermer",
        
        // Help Content
        "objective": "Objectif",
        "objective_description": "Devinez l'artiste vedette du jour en 10 tentatives ou moins.",
        "hints": "Indices",
        "hints_description": "Après chaque supposition, vous recevrez des indices sur l'artiste, y compris le sexe, le pays, l'année de début, le genre, s'il s'agit d'un solo ou d'un groupe, et leur classement de popularité Spotify.",
        "color_coding": "Codage Couleur",
        "color_coding_description": "🟢 Vert: Information correcte\n🟡 Jaune: Proche mais pas exact\n⚪ Gris: Information incorrecte",
        "daily_challenge": "Défi Quotidien",
        "daily_challenge_description": "Un nouvel artiste est mis en vedette chaque jour. Revenez demain pour un nouveau défi!",
        
        // Hints
        "popularity": "Popularité",
        "followers": "Abonnés",
        "genres": "Genres",
        "country": "Pays",
        "debut_year": "Année de Début",
        "albums": "Albums",
        
        // Hint Card Titles
        "Genre": "Genre",
        "Country": "Pays",
        "Debut Year": "Année de Début",
        "Gender": "Sexe",
        "Type": "Type",
        "Popularity": "Popularité",
        
        // Common
        "cancel": "Annuler",
        "done": "Terminé",
        "ok": "OK",
        "yes": "Oui",
        "no": "Non",
        "new_game": "Nouvelle Partie",
        
        // Additional strings
        "play_preview": "Lire l'Aperçu",
        "pause_preview": "Mettre en Pause",
        "no_image": "Pas d'Image",
        
        // Rating
        "enjoying_spolle": "Vous aimez Spolle?",
        "rate_us_description": "Si vous adorez jouer à notre jeu de devinettes d'artistes quotidien, prenez un moment pour nous noter sur l'App Store!",
        "rate_spolle": "Noter Spolle",
        "maybe_later": "Peut-être Plus Tard",
        
        // Game Screen
        "guess_daily_artist_spotify": "Devinez l'artiste quotidien de Spotify",
        "genre_label": "Genre",
        "country_label": "Pays",
        "debut_year_label": "Année de Début",
        



    ]
    
    // MARK: - Spanish Strings
    private static let spanishStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Adivinanza Diaria",
        "guess_the_artist": "Adivina el Artista",
        "challenge_yourself": "Desafíate con un nuevo artista.",
        "start_the_game": "Comenzar el Juego",
        
        // Game View
        "enter_your_guess": "Ingresa tu suposición",
        "submit_guess": "Enviar Suposición",
        "remaining_guesses": "Intentos Restantes",
        "your_guesses": "Tus Suposiciones",
        "correct": "🟢 Correcto",
        "close_match": "🟡 Cerca",
        "wrong": "⚪ Incorrecto",
        "latest_guess_first": "Última suposición mostrada primero",
        "latest": "ÚLTIMO",
        
        // Game Results
        "correct_celebration": "🎉 ¡Correcto!",
        "game_over": "¡Juego Terminado!",
        "you_guessed": "¡Adivinaste %@!",
        "answer_was": "La respuesta era: %@",
        "view_result": "Ver Resultado",
        
        // Success View
        "congratulations": "¡Felicitaciones!",
        "you_got_it": "¡Lo lograste!",
        "better_luck": "¡Mejor suerte la próxima vez!",
        "the_artist_was": "El artista era",
        "play_again": "Jugar de Nuevo",
        "share_result": "Compartir Resultado",
        "back_to_menu": "Volver al Menú",
        
        // Settings
        "settings": "Configuración",
        "language": "Idioma",
        "select_language": "Seleccionar Idioma",
        "theme": "Tema",
        "dark_mode": "Modo Oscuro",
        "light_mode": "Modo Claro",
        
        // Help
        "help": "Ayuda",
        "how_to_play": "Cómo Jugar",
        "game_rules": "Reglas del Juego",
        "close": "Cerrar",
        
        // Help Content
        "objective": "Objetivo",
        "objective_description": "Adivina el artista destacado del día en 10 intentos o menos.",
        "hints": "Pistas",
        "hints_description": "Después de cada suposición, recibirás pistas sobre el artista incluyendo género, país, año de debut, género musical, si es solista o grupo, y su ranking de popularidad en Spotify.",
        "color_coding": "Codificación de Colores",
        "color_coding_description": "🟢 Verde: Información correcta\n🟡 Amarillo: Cerca pero no exacto\n⚪ Gris: Información incorrecta",
        "daily_challenge": "Desafío Diario",
        "daily_challenge_description": "Un nuevo artista es destacado cada día. ¡Vuelve mañana para un nuevo desafío!",
        
        // Hints
        "popularity": "Popularidad",
        "followers": "Seguidores",
        "genres": "Géneros",
        "country": "País",
        "debut_year": "Año de Debut",
        "albums": "Álbumes",
        
        // Hint Card Titles
        "Genre": "Género",
        "Country": "País",
        "Debut Year": "Año de Debut",
        "Gender": "Género",
        "Type": "Tipo",
        "Popularity": "Popularidad",
        
        // Common
        "cancel": "Cancelar",
        "done": "Hecho",
        "ok": "OK",
        "yes": "Sí",
        "no": "No",
        "new_game": "Nuevo Juego",
        
        // Additional strings
        "play_preview": "Reproducir Vista Previa",
        "pause_preview": "Pausar Vista Previa",
        "no_image": "Sin Imagen",
        
        // Rating
        "enjoying_spolle": "¿Disfrutando Spolle?",
        "rate_us_description": "Si te encanta jugar nuestro juego diario de adivinanzas de artistas, ¡por favor tómate un momento para calificarnos en el App Store!",
        "rate_spolle": "Calificar Spolle",
        "maybe_later": "Tal vez Más Tarde",
        
        // Game Screen
        "guess_daily_artist_spotify": "Adivina el artista diario de Spotify",
        "genre_label": "Género",
        "country_label": "País",
        "debut_year_label": "Año de Debut",
        



    ]
    
    // MARK: - Portuguese Strings
    private static let portugueseStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Palpite Diário",
        "guess_the_artist": "Adivinhe o Artista",
        "challenge_yourself": "Desafie-se com um novo artista.",
        "start_the_game": "Começar o Jogo",
        
        // Game View
        "enter_your_guess": "Digite seu palpite",
        "submit_guess": "Enviar Palpite",
        "remaining_guesses": "Tentativas Restantes",
        "your_guesses": "Seus Palpites",
        "correct": "🟢 Correto",
        "close_match": "🟡 Perto",
        "wrong": "⚪ Errado",
        "latest_guess_first": "Último palpite mostrado primeiro",
        "latest": "ÚLTIMO",
        
        // Game Results
        "correct_celebration": "🎉 Correto!",
        "game_over": "Fim de Jogo!",
        "you_guessed": "Você adivinhou %@!",
        "answer_was": "A resposta era: %@",
        "view_result": "Ver Resultado",
        
        // Success View
        "congratulations": "Parabéns!",
        "you_got_it": "Você acertou!",
        "better_luck": "Mais sorte na próxima vez!",
        "the_artist_was": "O artista era",
        "play_again": "Jogar Novamente",
        "share_result": "Compartilhar Resultado",
        "back_to_menu": "Voltar ao Menu",
        
        // Settings
        "settings": "Configurações",
        "language": "Idioma",
        "select_language": "Selecionar Idioma",
        "theme": "Tema",
        "dark_mode": "Modo Escuro",
        "light_mode": "Modo Claro",
        
        // Help
        "help": "Ajuda",
        "how_to_play": "Como Jogar",
        "game_rules": "Regras do Jogo",
        "close": "Fechar",
        
        // Help Content
        "objective": "Objetivo",
        "objective_description": "Adivinhe o artista em destaque do dia em 10 tentativas ou menos.",
        "hints": "Dicas",
        "hints_description": "Após cada palpite, você receberá dicas sobre o artista incluindo gênero, país, ano de estreia, gênero musical, se é solo ou grupo, e seu ranking de popularidade no Spotify.",
        "color_coding": "Codificação de Cores",
        "color_coding_description": "🟢 Verde: Informação correta\n🟡 Amarelo: Perto mas não exato\n⚪ Cinza: Informação incorreta",
        "daily_challenge": "Desafio Diário",
        "daily_challenge_description": "Um novo artista é destacado todos os dias. Volte amanhã para um novo desafio!",
        
        // Hints
        "popularity": "Popularidade",
        "followers": "Seguidores",
        "genres": "Gêneros",
        "country": "País",
        "debut_year": "Ano de Estreia",
        "albums": "Álbuns",
        
        // Hint Card Titles
        "Genre": "Gênero",
        "Country": "País",
        "Debut Year": "Ano de Estreia",
        "Gender": "Gênero",
        "Type": "Tipo",
        "Popularity": "Popularidade",
        
        // Common
        "cancel": "Cancelar",
        "done": "Feito",
        "ok": "OK",
        "yes": "Sim",
        "no": "Não",
        "new_game": "Novo Jogo",
        
        // Additional strings
        "play_preview": "Reproduzir Prévia",
        "pause_preview": "Pausar Prévia",
        "no_image": "Sem Imagem",
        
        // Rating
        "enjoying_spolle": "Gostando do Spolle?",
        "rate_us_description": "Se você adora jogar nosso jogo diário de adivinhar artistas, por favor reserve um momento para nos avaliar na App Store!",
        "rate_spolle": "Avaliar Spolle",
        "maybe_later": "Talvez Mais Tarde",
        
        // Game Screen
        "guess_daily_artist_spotify": "Adivinhe o artista diário do Spotify",
        "genre_label": "Gênero",
        "country_label": "País",
        "debut_year_label": "Ano de Estreia",
        



    ]
    
    // MARK: - Russian Strings
    private static let russianStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Ежедневная Угадайка",
        "guess_the_artist": "Угадай Артиста",
        "challenge_yourself": "Испытай себя с новым артистом.",
        "start_the_game": "Начать Игру",
        
        // Game View
        "enter_your_guess": "Введите вашу догадку",
        "submit_guess": "Отправить Догадку",
        "remaining_guesses": "Оставшиеся Попытки",
        "your_guesses": "Ваши Догадки",
        "correct": "🟢 Правильно",
        "close_match": "🟡 Близко",
        "wrong": "⚪ Неправильно",
        "latest_guess_first": "Последняя догадка показана первой",
        "latest": "ПОСЛЕДНЯЯ",
        
        // Game Results
        "correct_celebration": "🎉 Правильно!",
        "game_over": "Игра Окончена!",
        "you_guessed": "Вы угадали %@!",
        "answer_was": "Ответ был: %@",
        "view_result": "Посмотреть Результат",
        
        // Success View
        "congratulations": "Поздравляем!",
        "you_got_it": "Вы справились!",
        "better_luck": "Удачи в следующий раз!",
        "the_artist_was": "Артистом был",
        "play_again": "Играть Снова",
        "share_result": "Поделиться Результатом",
        "back_to_menu": "Назад в Меню",
        
        // Settings
        "settings": "Настройки",
        "language": "Язык",
        "select_language": "Выбрать Язык",
        "theme": "Тема",
        "dark_mode": "Темный Режим",
        "light_mode": "Светлый Режим",
        
        // Help
        "help": "Помощь",
        "how_to_play": "Как Играть",
        "game_rules": "Правила Игры",
        "close": "Закрыть",
        
        // Help Content
        "objective": "Цель",
        "objective_description": "Угадайте ежедневного избранного артиста за 10 попыток или меньше.",
        "hints": "Подсказки",
        "hints_description": "После каждой догадки вы получите подсказки об артисте, включая пол, страну, год дебюта, жанр, соло или группа, и их рейтинг популярности в Spotify.",
        "color_coding": "Цветовое Кодирование",
        "color_coding_description": "🟢 Зеленый: Правильная информация\n🟡 Желтый: Близко, но не точно\n⚪ Серый: Неправильная информация",
        "daily_challenge": "Ежедневный Вызов",
        "daily_challenge_description": "Каждый день представлен новый артист. Возвращайтесь завтра за новым вызовом!",
        
        // Hints
        "popularity": "Популярность",
        "followers": "Подписчики",
        "genres": "Жанры",
        "country": "Страна",
        "debut_year": "Год Дебюта",
        "albums": "Альбомы",
        
        // Hint Card Titles
        "Genre": "Жанр",
        "Country": "Страна",
        "Debut Year": "Год Дебюта",
        "Gender": "Пол",
        "Type": "Тип",
        "Popularity": "Популярность",
        
        // Common
        "cancel": "Отмена",
        "done": "Готово",
        "ok": "ОК",
        "yes": "Да",
        "no": "Нет",
        "new_game": "Новая Игра",
        
        // Additional strings
        "play_preview": "Воспроизвести Превью",
        "pause_preview": "Приостановить Превью",
        "no_image": "Нет Изображения",
        
        // Rating
        "enjoying_spolle": "Нравится Spolle?",
        "rate_us_description": "Если вам нравится играть в нашу ежедневную игру-угадайку артистов, пожалуйста, найдите минутку, чтобы оценить нас в App Store!",
        "rate_spolle": "Оценить Spolle",
        "maybe_later": "Может Быть Позже",
        
        // Game Screen
        "guess_daily_artist_spotify": "Угадайте ежедневного артиста из Spotify",
        "genre_label": "Жанр",
        "country_label": "Страна",
        "debut_year_label": "Год Дебюта",
        



    ]
    
    // MARK: - Ukrainian Strings
    private static let ukrainianStrings: [String: String] = [
        // Main Menu
        "daily_guess": "Щоденна Вгадайка",
        "guess_the_artist": "Вгадай Артиста",
        "challenge_yourself": "Випробуй себе з новим артистом.",
        "start_the_game": "Почати Гру",
        
        // Game View
        "enter_your_guess": "Введіть вашу здогадку",
        "submit_guess": "Надіслати Здогадку",
        "remaining_guesses": "Залишилося Спроб",
        "your_guesses": "Ваші Здогадки",
        "correct": "🟢 Правильно",
        "close_match": "🟡 Близько",
        "wrong": "⚪ Неправильно",
        "latest_guess_first": "Остання здогадка показана першою",
        "latest": "ОСТАННЯ",
        
        // Game Results
        "correct_celebration": "🎉 Правильно!",
        "game_over": "Гра Закінчена!",
        "you_guessed": "Ви вгадали %@!",
        "answer_was": "Відповідь була: %@",
        "view_result": "Переглянути Результат",
        
        // Success View
        "congratulations": "Вітаємо!",
        "you_got_it": "Ви впоралися!",
        "better_luck": "Удачі наступного разу!",
        "the_artist_was": "Артистом був",
        "play_again": "Грати Знову",
        "share_result": "Поділитися Результатом",
        "back_to_menu": "Назад до Меню",
        
        // Settings
        "settings": "Налаштування",
        "language": "Мова",
        "select_language": "Вибрати Мову",
        "theme": "Тема",
        "dark_mode": "Темний Режим",
        "light_mode": "Світлий Режим",
        
        // Help
        "help": "Допомога",
        "how_to_play": "Як Грати",
        "game_rules": "Правила Гри",
        "close": "Закрити",
        
        // Help Content
        "objective": "Мета",
        "objective_description": "Вгадайте щоденного обраного артиста за 10 спроб або менше.",
        "hints": "Підказки",
        "hints_description": "Після кожної здогадки ви отримаєте підказки про артиста, включаючи стать, країну, рік дебюту, жанр, соло чи група, та їх рейтинг популярності в Spotify.",
        "color_coding": "Кольорове Кодування",
        "color_coding_description": "🟢 Зелений: Правильна інформація\n🟡 Жовтий: Близько, але не точно\n⚪ Сірий: Неправильна інформація",
        "daily_challenge": "Щоденний Виклик",
        "daily_challenge_description": "Кожного дня представлений новий артист. Повертайтесь завтра за новим викликом!",
        
        // Hints
        "popularity": "Популярність",
        "followers": "Підписники",
        "genres": "Жанри",
        "country": "Країна",
        "debut_year": "Рік Дебюту",
        "albums": "Альбоми",
        
        // Hint Card Titles
        "Genre": "Жанр",
        "Country": "Країна",
        "Debut Year": "Рік Дебюту",
        "Gender": "Стать",
        "Type": "Тип",
        "Popularity": "Популярність",
        
        // Common
        "cancel": "Скасувати",
        "done": "Готово",
        "ok": "ОК",
        "yes": "Так",
        "no": "Ні",
        "new_game": "Нова Гра",
        
        // Additional strings
        "play_preview": "Відтворити Превʼю",
        "pause_preview": "Призупинити Превʼю",
        "no_image": "Немає Зображення",
        
        // Rating
        "enjoying_spolle": "Подобається Spolle?",
        "rate_us_description": "Якщо вам подобається грати в нашу щоденну гру-вгадайку артистів, будь ласка, знайдіть хвилинку, щоб оцінити нас в App Store!",
        "rate_spolle": "Оцінити Spolle",
        "maybe_later": "Можливо Пізніше",
        
        // Game Screen
        "guess_daily_artist_spotify": "Вгадайте щоденного артиста зі Spotify",
        "genre_label": "Жанр",
        "country_label": "Країна",
        "debut_year_label": "Рік Дебюту",
        



    ]
    
    // MARK: - Chinese (Simplified) Strings
    private static let chineseSimplifiedStrings: [String: String] = [
        // Main Menu
        "daily_guess": "每日猜测",
        "guess_the_artist": "猜艺术家",
        "challenge_yourself": "用新艺术家挑战自己。",
        "start_the_game": "开始游戏",
        
        // Game View
        "enter_your_guess": "输入您的猜测",
        "submit_guess": "提交猜测",
        "remaining_guesses": "剩余猜测次数",
        "your_guesses": "您的猜测",
        "correct": "🟢 正确",
        "close_match": "🟡 接近",
        "wrong": "⚪ 错误",
        "latest_guess_first": "最新猜测显示在前",
        "latest": "最新",
        
        // Game Results
        "correct_celebration": "🎉 正确！",
        "game_over": "游戏结束！",
        "you_guessed": "您猜对了 %@！",
        "answer_was": "答案是：%@",
        "view_result": "查看结果",
        
        // Success View
        "congratulations": "恭喜！",
        "you_got_it": "您答对了！",
        "better_luck": "下次好运！",
        "the_artist_was": "艺术家是",
        "play_again": "再次游戏",
        "share_result": "分享结果",
        "back_to_menu": "返回菜单",
        
        // Settings
        "settings": "设置",
        "language": "语言",
        "select_language": "选择语言",
        "theme": "主题",
        "dark_mode": "深色模式",
        "light_mode": "浅色模式",
        
        // Help
        "help": "帮助",
        "how_to_play": "如何游戏",
        "game_rules": "游戏规则",
        "close": "关闭",
        
        // Help Content
        "objective": "目标",
        "objective_description": "在10次或更少的尝试中猜出每日特色艺术家。",
        "hints": "提示",
        "hints_description": "每次猜测后，您将收到关于艺术家的提示，包括性别、国家、出道年份、音乐类型、是独唱还是组合，以及他们在Spotify上的人气排名。",
        "color_coding": "颜色编码",
        "color_coding_description": "🟢 绿色：正确信息\n🟡 黄色：接近但不准确\n⚪ 灰色：错误信息",
        "daily_challenge": "每日挑战",
        "daily_challenge_description": "每天都会推出一位新艺术家。明天再来接受新挑战！",
        
        // Hints
        "popularity": "人气",
        "followers": "粉丝",
        "genres": "音乐类型",
        "country": "国家",
        "debut_year": "出道年份",
        "albums": "专辑",
        
        // Hint Card Titles
        "Genre": "音乐类型",
        "Country": "国家",
        "Debut Year": "出道年份",
        "Gender": "性别",
        "Type": "类型",
        "Popularity": "人气",
        
        // Common
        "cancel": "取消",
        "done": "完成",
        "ok": "确定",
        "yes": "是",
        "no": "否",
        "new_game": "新游戏",
        
        // Additional strings
        "play_preview": "播放预览",
        "pause_preview": "暂停预览",
        "no_image": "无图片",
        
        // Rating
        "enjoying_spolle": "喜欢Spolle吗？",
        "rate_us_description": "如果您喜欢我们的每日艺术家猜测游戏，请花一点时间在App Store上为我们评分！",
        "rate_spolle": "为Spolle评分",
        "maybe_later": "稍后再说",
        
        // Game Screen
        "guess_daily_artist_spotify": "猜测Spotify上的每日艺术家",
        "genre_label": "音乐类型",
        "country_label": "国家",
        "debut_year_label": "出道年份",
        



    ]
    
    // MARK: - Japanese Strings
    private static let japaneseStrings: [String: String] = [
        // Main Menu
        "daily_guess": "デイリー推測",
        "guess_the_artist": "アーティストを当てよう",
        "challenge_yourself": "新しいアーティストで自分に挑戦しよう。",
        "start_the_game": "ゲーム開始",
        
        // Game View
        "enter_your_guess": "推測を入力してください",
        "submit_guess": "推測を送信",
        "remaining_guesses": "残り推測回数",
        "your_guesses": "あなたの推測",
        "correct": "🟢 正解",
        "close_match": "🟡 近い",
        "wrong": "⚪ 不正解",
        "latest_guess_first": "最新の推測を最初に表示",
        "latest": "最新",
        
        // Game Results
        "correct_celebration": "🎉 正解！",
        "game_over": "ゲーム終了！",
        "you_guessed": "%@を当てました！",
        "answer_was": "答えは：%@",
        "view_result": "結果を見る",
        
        // Success View
        "congratulations": "おめでとうございます！",
        "you_got_it": "正解です！",
        "better_luck": "次回頑張って！",
        "the_artist_was": "アーティストは",
        "play_again": "もう一度プレイ",
        "share_result": "結果をシェア",
        "back_to_menu": "メニューに戻る",
        
        // Settings
        "settings": "設定",
        "language": "言語",
        "select_language": "言語を選択",
        "theme": "テーマ",
        "dark_mode": "ダークモード",
        "light_mode": "ライトモード",
        
        // Help
        "help": "ヘルプ",
        "how_to_play": "遊び方",
        "game_rules": "ゲームルール",
        "close": "閉じる",
        
        // Help Content
        "objective": "目的",
        "objective_description": "10回以下の試行で毎日の注目アーティストを当ててください。",
        "hints": "ヒント",
        "hints_description": "各推測の後、性別、国、デビュー年、ジャンル、ソロかグループか、Spotifyでの人気ランキングなど、アーティストに関するヒントが表示されます。",
        "color_coding": "色分け",
        "color_coding_description": "🟢 緑：正しい情報\n🟡 黄：近いが正確ではない\n⚪ グレー：間違った情報",
        "daily_challenge": "デイリーチャレンジ",
        "daily_challenge_description": "毎日新しいアーティストが登場します。明日また新しいチャレンジに戻ってきてください！",
        
        // Hints
        "popularity": "人気度",
        "followers": "フォロワー",
        "genres": "ジャンル",
        "country": "国",
        "debut_year": "デビュー年",
        "albums": "アルバム",
        
        // Hint Card Titles
        "Genre": "ジャンル",
        "Country": "国",
        "Debut Year": "デビュー年",
        "Gender": "性別",
        "Type": "タイプ",
        "Popularity": "人気度",
        
        // Common
        "cancel": "キャンセル",
        "done": "完了",
        "ok": "OK",
        "yes": "はい",
        "no": "いいえ",
        "new_game": "新しいゲーム",
        
        // Additional strings
        "play_preview": "プレビュー再生",
        "pause_preview": "プレビュー一時停止",
        "no_image": "画像なし",
        
        // Rating
        "enjoying_spolle": "Spolleを楽しんでいますか？",
        "rate_us_description": "毎日のアーティスト推測ゲームを気に入っていただけましたら、App Storeで評価をお願いします！",
        "rate_spolle": "Spolleを評価",
        "maybe_later": "後で",
        
        // Game Screen
        "guess_daily_artist_spotify": "Spotifyの毎日のアーティストを当てよう",
        "genre_label": "ジャンル",
        "country_label": "国",
        "debut_year_label": "デビュー年",
        



    ]
}