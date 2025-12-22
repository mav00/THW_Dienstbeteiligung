<?php
$dataDir = __DIR__ . '/data';
$allowedFiles = ['persons.yaml', 'dienste.yaml', 'abwesenheiten.yaml', 'anwesenheit.yaml'];

if (!is_dir($dataDir)) mkdir($dataDir, 0777, true);

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$filename = basename($path);

if (!in_array($filename, $allowedFiles)) {
    http_response_code(400);
    die("Invalid filename");
}

$filePath = $dataDir . '/' . $filename;

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (file_exists($filePath)) {
        header('Content-Type: application/x-yaml');
        readfile($filePath);
    } else {
        echo "";
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    file_put_contents($filePath, $input);
    echo json_encode(["message" => "Saved"]);
}
?>