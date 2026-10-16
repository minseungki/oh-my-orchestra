#!/usr/bin/env node
// 오케스트라 산출물 필수 필드 검사
// 사용법: node check-artifact.js <path/to/plan.json|implementation.json|test-result.json|review.json|security-review.json>
// exit 0 = 통과, exit 1 = 누락/형식 오류, exit 2 = 사용법 오류

const fs = require('fs');
const path = require('path');

const REQUIRED = {
    'plan.json': {
        summary: 'string', size: ['S', 'M', 'L'], risk: ['low', 'medium', 'high'],
        files_to_read: 'array', files_to_edit: 'array', files_not_to_edit: 'array',
        steps: 'array', tests: 'array', test_commands: 'array',
        security_review_required: 'boolean', assumptions: 'array', decisions_pending: 'array',
        stop_conditions: 'array'
    },
    'implementation.json': {
        status: ['completed', 'blocked', 'partial'], summary: 'string',
        files_changed: 'array', commands_run: 'array', blocked_reasons: 'array', not_changed: 'array'
    },
    'test-result.json': {
        status: ['pass', 'fail', 'partial'], commands_run: 'array',
        passed: 'array', failed: 'array', not_run: 'array'
    },
    'review.json': {
        verdict: ['approved', 'needs_changes', 'blocked'], issues: 'array',
        missing_tests: 'array', policy_violations: 'array'
    },
    'security-review.json': {
        verdict: ['approved', 'needs_changes', 'blocked'], findings: 'array',
        human_approval_required: 'boolean'
    }
};

function typeOk(value, rule) {
    if (Array.isArray(rule)) {
        return rule.includes(value);
    }
    if (rule === 'array') {
        return Array.isArray(value);
    }
    return typeof value === rule;
}

const file = process.argv[2];
if (!file) {
    console.error('사용법: node check-artifact.js <artifact.json>');
    process.exit(2);
}

const spec = REQUIRED[path.basename(file)];
if (!spec) {
    console.error(`알 수 없는 산출물: ${path.basename(file)} (지원: ${Object.keys(REQUIRED).join(', ')})`);
    process.exit(2);
}

let data;
try {
    data = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch (e) {
    console.error(`FAIL ${file}: 읽기/JSON 파싱 실패 - ${e.message}`);
    process.exit(1);
}

const errors = [];
for (const [key, rule] of Object.entries(spec)) {
    if (!(key in data)) {
        errors.push(`누락: ${key}`);
    } else if (!typeOk(data[key], rule)) {
        errors.push(`형식 오류: ${key} (기대: ${Array.isArray(rule) ? rule.join('|') : rule})`);
    }
}

// 요구사항 정의서가 있는 작업이면 plan.json에 req_trace가 있어야 한다
if (path.basename(file) === 'plan.json' && fs.existsSync(path.join(path.dirname(file), 'requirements.md'))) {
    if (!Array.isArray(data.req_trace) || data.req_trace.length === 0) {
        errors.push('누락: req_trace (requirements.md가 있는 작업)');
    }
}

if (errors.length) {
    console.error(`FAIL ${file}\n- ${errors.join('\n- ')}`);
    process.exit(1);
}
console.log(`OK ${file}`);
