package com.hango.hango_backend.util;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class VectorUtilTest {

    // =================================================================
    // toJson / fromJson
    // =================================================================

    @Test
    void toJsonThenFromJsonShouldRoundTripVector() {
        List<Double> original = List.of(0.1, 0.2, 0.3);

        String json = VectorUtil.toJson(original);
        List<Double> result = VectorUtil.fromJson(json);

        assertEquals(original, result);
    }

    @Test
    void fromJsonShouldThrowRuntimeExceptionWhenJsonIsMalformed() {
        assertThrows(RuntimeException.class, () -> VectorUtil.fromJson("not valid json"));
    }

    // =================================================================
    // cosineSimilarity
    // =================================================================

    @Test
    void cosineSimilarityShouldReturnOneForIdenticalVectors() {
        List<Double> a = List.of(1.0, 2.0, 3.0);

        double result = VectorUtil.cosineSimilarity(a, a);

        assertEquals(1.0, result, 0.0001);
    }

    @Test
    void cosineSimilarityShouldReturnZeroForOrthogonalVectors() {
        List<Double> a = List.of(1.0, 0.0);
        List<Double> b = List.of(0.0, 1.0);

        double result = VectorUtil.cosineSimilarity(a, b);

        assertEquals(0.0, result, 0.0001);
    }

    @Test
    void cosineSimilarityShouldReturnNegativeOneForOppositeVectors() {
        List<Double> a = List.of(1.0, 0.0);
        List<Double> b = List.of(-1.0, 0.0);

        double result = VectorUtil.cosineSimilarity(a, b);

        assertEquals(-1.0, result, 0.0001);
    }

    @Test
    void cosineSimilarityShouldThrowWhenDimensionsMismatch() {
        List<Double> a = List.of(1.0, 2.0);
        List<Double> b = List.of(1.0, 2.0, 3.0);

        assertThrows(IllegalArgumentException.class, () -> VectorUtil.cosineSimilarity(a, b));
    }

    @Test
    void cosineSimilarityShouldReturnZeroWhenEitherVectorIsAllZeros() {
        List<Double> zero = List.of(0.0, 0.0);
        List<Double> other = List.of(1.0, 1.0);

        double result = VectorUtil.cosineSimilarity(zero, other);

        assertEquals(0.0, result, 0.0001);
    }
}
