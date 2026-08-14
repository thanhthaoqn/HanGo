package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SystemConfigService {

    private final SystemParameterRepository systemParameterRepository;

    public String getConfigValue(String type, String key, String defaultValue) {
        return systemParameterRepository.findByParamTypeAndParamKey(type, key)
                .map(SystemParameter::getParamValue)
                .orElse(defaultValue);
    }

    public Map<String, String> getAllConfigsByType(String type) {
        List<SystemParameter> params = systemParameterRepository.findByParamTypeAndIsActiveTrue(type);
        return params.stream().collect(Collectors.toMap(SystemParameter::getParamKey, SystemParameter::getParamValue));
    }

    @Transactional
    public void updateConfigs(String type, Map<String, String> configs) {
        for (Map.Entry<String, String> entry : configs.entrySet()) {
            Optional<SystemParameter> existingOpt = systemParameterRepository.findByParamTypeAndParamKey(type, entry.getKey());
            if (existingOpt.isPresent()) {
                SystemParameter param = existingOpt.get();
                param.setParamValue(entry.getValue());
                systemParameterRepository.save(param);
            } else {
                SystemParameter newParam = SystemParameter.builder()
                        .paramType(type)
                        .paramKey(entry.getKey())
                        .paramValue(entry.getValue())
                        .isActive(true)
                        .build();
                systemParameterRepository.save(newParam);
            }
        }
    }
}
