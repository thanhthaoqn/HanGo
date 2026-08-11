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
    private final WebClient webClient = WebClient.builder()
            .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
            .build();

    private static final Pattern VIDEO_ID_PATTERN = Pattern.compile(
            "(?:v=|/v/|youtu\\.be/|/embed/|/shorts/|^)([a-zA-Z0-9_-]{11})"
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
            String jsonStr = extractJson(html, "ytInitialPlayerResponse");
            if (jsonStr == null) {
                log.warn("ytInitialPlayerResponse not found in HTML for video: {}. Contains 'ytInitialPlayerResponse': {}, Contains 'captionTracks': {}. Snippet: {}", 
                        videoId, html.contains("ytInitialPlayerResponse"), html.contains("captionTracks"), html.length() > 400 ? html.substring(0, 400) : html);
                return null;
            }
            
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

            // 5. Parse XML to extract text and timestamps to build WebVTT
            StringBuilder transcriptBuilder = new StringBuilder();
            transcriptBuilder.append("WEBVTT\n\n");
            
            // Typical YouTube timed text XML: <text start="0" dur="4.25">...</text>
            Pattern textTagPattern = Pattern.compile("<text\\s+start=\"([^\"]+)\"(?:\\s+dur=\"([^\"]+)\")?[^>]*>(.*?)</text>");
            Matcher textMatcher = textTagPattern.matcher(xmlCaptions);
            
            int counter = 1;
            while (textMatcher.find()) {
                String startStr = textMatcher.group(1);
                String durStr = textMatcher.group(2);
                String line = textMatcher.group(3);
                
                double start = Double.parseDouble(startStr);
                double dur = (durStr != null && !durStr.isEmpty()) ? Double.parseDouble(durStr) : 2.0; // default duration
                double end = start + dur;

                // Unescape basic XML entities
                line = line.replace("&amp;", "&")
                           .replace("&quot;", "\"")
                           .replace("&#39;", "'")
                           .replace("&lt;", "<")
                           .replace("&gt;", ">");
                           
                transcriptBuilder.append(counter++).append("\n");
                transcriptBuilder.append(formatVttTime(start)).append(" --> ").append(formatVttTime(end)).append("\n");
                transcriptBuilder.append(line).append("\n\n");
            }

            String finalTranscript = transcriptBuilder.toString().trim();
            if (finalTranscript.equals("WEBVTT")) {
                return null;
            }
            
            log.info("Successfully fetched transcript for video {}. Length: {}", videoId, finalTranscript.length());
            return finalTranscript;

        } catch (Exception e) {
            log.error("Failed to fetch transcript for video {}: {}", videoId, e.getMessage());
            return null;
        }
    }

    private String formatVttTime(double totalSeconds) {
        int hours = (int) (totalSeconds / 3600);
        int minutes = (int) ((totalSeconds % 3600) / 60);
        int seconds = (int) (totalSeconds % 60);
        int milliseconds = (int) ((totalSeconds - (int) totalSeconds) * 1000);
        return String.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds);
    }

    private String extractJson(String html, String marker) {
        int idx = html.indexOf(marker);
        if (idx == -1) return null;
        int start = html.indexOf('{', idx + marker.length());
        if (start == -1) return null;

        int braceCount = 0;
        boolean inString = false;
        boolean escape = false;

        for (int i = start; i < html.length(); i++) {
            char c = html.charAt(i);
            if (escape) {
                escape = false;
                continue;
            }
            if (c == '\\' && inString) {
                escape = true;
                continue;
            }
            if (c == '"') {
                inString = !inString;
                continue;
            }
            if (!inString) {
                if (c == '{') braceCount++;
                else if (c == '}') {
                    braceCount--;
                    if (braceCount == 0) {
                        return html.substring(start, i + 1);
                    }
                }
            }
        }
        return null;
    }
}
