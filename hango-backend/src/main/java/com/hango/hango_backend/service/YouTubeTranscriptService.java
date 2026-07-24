package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Slf4j
@Service
@RequiredArgsConstructor
public class YouTubeTranscriptService {

    private final ObjectMapper objectMapper;
    private final WebClient webClient = WebClient.builder().build();

    private static final Pattern VIDEO_ID_PATTERN = Pattern.compile(
            "(?:v=|/v/|youtu\\.be/|/embed/|/shorts/|^)([a-zA-Z0-9_-]{11})"
    );
    
    private static final Pattern YT_INITIAL_PLAYER_RESPONSE_PATTERN = Pattern.compile(
            "ytInitialPlayerResponse\\s*=\\s*(\\{.*?\\});"
    );

    /**
     * Tries to extract a YouTube Video ID from a given text (which might be a URL or HTML content).
     */
    public String extractVideoId(String text) {
        if (text == null || text.isBlank()) return null;
        Matcher matcher = VIDEO_ID_PATTERN.matcher(text);
        if (matcher.find()) {
            return matcher.group(1);
        }
        return null;
    }

    /**
     * Fetches the transcript for a given YouTube video URL or ID.
     * Returns null if no transcript is found or an error occurs.
     */
    public String fetchTranscript(String urlOrText) {
        String videoId = extractVideoId(urlOrText);
        if (videoId == null) {
            return null;
        }

        try {
            // 1. Fetch the YouTube video page HTML
            String videoUrl = "https://www.youtube.com/watch?v=" + videoId;
            String html = webClient.get()
                    .uri(videoUrl)
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                    .header("Accept-Language", "en-US,en;q=0.9,vi;q=0.8")
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();

            if (html == null) return null;

            // 2. Extract ytInitialPlayerResponse JSON
            Matcher jsonMatcher = YT_INITIAL_PLAYER_RESPONSE_PATTERN.matcher(html);
            if (!jsonMatcher.find()) {
                log.warn("ytInitialPlayerResponse not found in HTML for video: {}", videoId);
                return null;
            }
            
            String jsonStr = jsonMatcher.group(1);
            JsonNode rootNode = objectMapper.readTree(jsonStr);
            
            // 3. Find the captions base URL
            JsonNode captionsNode = rootNode.path("captions").path("playerCaptionsTracklistRenderer").path("captionTracks");
            if (captionsNode.isMissingNode() || !captionsNode.isArray() || captionsNode.isEmpty()) {
                log.info("No captions found for video: {}", videoId);
                return null;
            }
            
            // Try to find English or Vietnamese, default to the first one
            String captionsUrl = null;
            for (JsonNode track : captionsNode) {
                String languageCode = track.path("languageCode").asText("");
                if (languageCode.startsWith("en") || languageCode.startsWith("vi")) {
                    captionsUrl = track.path("baseUrl").asText();
                    break;
                }
            }
            
            if (captionsUrl == null) {
                captionsUrl = captionsNode.get(0).path("baseUrl").asText();
            }

            if (captionsUrl == null || captionsUrl.isBlank()) {
                return null;
            }

            // 4. Fetch the XML captions
            String xmlCaptions = webClient.get()
                    .uri(captionsUrl)
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
                    
            if (xmlCaptions == null) return null;

            // 5. Parse XML to extract text (simple regex for <text> tags)
            StringBuilder transcriptBuilder = new StringBuilder();
            Pattern textTagPattern = Pattern.compile("<text[^>]*>(.*?)</text>");
            Matcher textMatcher = textTagPattern.matcher(xmlCaptions);
            while (textMatcher.find()) {
                String line = textMatcher.group(1);
                // Unescape basic XML entities
                line = line.replace("&amp;", "&")
                           .replace("&quot;", "\"")
                           .replace("&#39;", "'")
                           .replace("&lt;", "<")
                           .replace("&gt;", ">");
                transcriptBuilder.append(line).append(" ");
            }

            String finalTranscript = transcriptBuilder.toString().trim();
            if (finalTranscript.isEmpty()) {
                return null;
            }
            
            log.info("Successfully fetched transcript for video {}. Length: {}", videoId, finalTranscript.length());
            return finalTranscript;

        } catch (Exception e) {
            log.error("Failed to fetch transcript for video {}: {}", videoId, e.getMessage());
            return null;
        }
    }
}
