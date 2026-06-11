import Foundation

// MARK: - AI Analysis Result

struct RadarAnalysis: Codable {
    let cleaned: String
    let elder: Double
    let date: Double
    let girlApproved: Double
    let office: Double
    let selfComfort: Double
    let impression: Double
    let review: String

    enum CodingKeys: String, CodingKey {
        case cleaned, elder, date, girlApproved, office, impression, review
        case selfComfort = "self"
    }
}

// MARK: - DeepSeek Service

final class DeepSeekService {

    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/chat/completions"
    private let model = "deepseek-chat"

    init() {
        // Injected via SWIFT_ACTIVE_COMPILATION_CONDITIONS from Config.xcconfig
        let raw = DEEPSEEK_API_KEY
        // Strip surrounding quotes from the macro expansion
        self.apiKey = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    /// Returns nil on any failure — caller treats this as "AI unavailable, proceed manually".
    func analyze(ocrText: String) async -> RadarAnalysis? {
        guard !apiKey.isEmpty, !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let prompt = """
        你是一位毒舌又懂行的香水评论家。根据 OCR 识别出的香水信息打分。

        先修正 OCR 文字中的拼写错误、格式混乱和断行错位，补全缩写（EDT→Eau de Toilette），
        整理成可读的香水全称。

        然后按6个社交场景维度评分。分数必须有明显差异——不要全部3分！好的香大胆给4.5-5，
        不适合的场景果断给1-2。像真人在推荐香水一样有态度。

        6个维度（0-5，必须拉开差距，避免集中在3-4分）：
        - 长辈好感：温和得体？见父母不突兀？
        - 约会引力：亲密距离的吸引力？暗器指数？
        - 闺蜜推荐：女生朋友会问"喷的什么"？
        - 职场安全：不打扰同事？低调有品？
        - 独处疗愈：自己闻着开心放松？
        - 初见印象：陌生人闻到觉得有品味？

        再写1-3句犀利点评。不要百科式废话。可以毒舌、可以吹爆、可以说"这件战袍只适合晚上"。
        如果识别不出来，评分全0，review写"无法识别"。

        OCR 原文：
        \(ocrText)

        只返回JSON：
        {"cleaned":"修正后全称","elder":4.5,"date":2,"girlApproved":5,"office":1.5,"self":3,"impression":5,"review":"毒舌点评"}
        """

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 1.2,
            "max_tokens": 500
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return parseResponse(data)
        } catch {
            return nil
        }
    }

    // MARK: - JSON Parsing

    private func parseResponse(_ data: Data) -> RadarAnalysis? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              var content = message["content"] as? String else {
            return nil
        }

        // Strip markdown code fences
        content = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = content.data(using: .utf8),
              let analysis = try? JSONDecoder().decode(RadarAnalysis.self, from: jsonData) else {
            return nil
        }

        return analysis
    }
}
