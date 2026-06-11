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
        你是一个真实的香水爱好者。根据 OCR 识别出的香水信息，给出你的真实感受。\
        你不是香评家，你就是一个喷了这支香出门的人。

        先修正 OCR 文字中的拼写错误和格式，补全缩写（EDT→Eau de Toilette）。

        然后对 6 个场景评分（0-5，要拉开差距，别全在中间值）：
        - 👴 长辈好感 - 💕 约会引力 - 👯 闺蜜推荐
        - 💼 职场安全 - 🧘 独处疗愈 - ✨ 初见印象

        短评规则：
        - 刚好 2 句话，≤35 字
        - 第一句说优点，第二句说缺点
        - 用"我"开头，像在跟朋友聊天
        - 参考香水的品牌、香调、浓度做判断，不要瞎编
        - 同一支香多次评分和点评应该稳定一致

        风格参考：
        TF 乌木："贵但值得，穿去约会气场全开。留香太久洗都洗不掉。"
        蓝风铃："夏天用清新到上头。五步散，三小时补一次。"
        大地："见长辈的安全牌，温润不张扬。年轻人用稍显老成。"
        旷野："女生闻了会主动靠近。办公室喷这个会被翻白眼。"

        评分参考：
        - 商业香（Chanel/Dior/Hermès）→ 场景覆盖面广
        - 小众 niche → 独特性强，长辈/职场偏低
        - EDP/Parfum 浓香 → 约会引力高，职场安全低
        - EDT/古龙水淡香 → 职场安全高，约会引力偏低

        OCR 原文：
        \(ocrText)

        只返回JSON：
        {"cleaned":"修正后香水名","elder":4,"date":5,"girlApproved":3.5,"office":2,"self":4,"impression":4.5,"review":"优点一句话。缺点一句话。"}
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
            "temperature": 0.7,
            "max_tokens": 400
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
