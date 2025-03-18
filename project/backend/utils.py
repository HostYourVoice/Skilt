"""Utility functions for the project."""

import tomllib
from pathlib import Path
from rich.logging import RichHandler
import logging


def load_config_file(config_file_path: str = None) -> dict:
    """
    Load a JSON configuration file.

    Args:
        config_file_path (str): Path to the configuration file.

    Returns:
        dict: Parsed TOML content.
    """
    if config_file_path is None:
        config_file_path = Path(__file__).resolve().parent.parent / "config.toml"

    try:
        with open(config_file_path, "rb") as file:
            return tomllib.load(file)
    except FileNotFoundError:
        raise FileNotFoundError(f"Configuration file not found: {config_file_path}")
    except tomllib.TOMLDecodeError:
        raise ValueError(f"Error decoding TOML from the file: {config_file_path}")


def get_openai_api_key(config_file_path: str = None) -> str:
    """
    Retrieve the OpenAI API key from the environment variable.

    Args:
        config_file_path (str): Path to the configuration file.


    Returns:
        str: OpenAI API key.
    """
    try:
        return load_config_file(config_file_path=config_file_path)["openai_api_key"]
    except KeyError:
        raise KeyError("OpenAI API key not found in the configuration file.")
    except Exception as e:
        raise RuntimeError(
            f"An error occurred while retrieving the OpenAI API key: {str(e)}"
        )


def get_logger(config_file_path: str = None, log_level_override: str = None) -> str:
    """
    Create the logging handler.

    Args:
        config_file_path (str): Path to the configuration file.

    Returns:
        Python logging handler
    """
    if log_level_override:
        log_level = log_level_override
    else:
        try:
            log_level = load_config_file(config_file_path=config_file_path)["log_level"]
        except KeyError:
            raise KeyError("Logger configuration not found in the configuration file.")
        except Exception as e:
            raise RuntimeError(
                f"An error occurred while retrieving the logger configuration: {str(e)}"
            )

    logging.basicConfig(
        level=log_level.upper(),
        format="WordSmith Backend (%(asctime)s): %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
        handlers=[RichHandler()],
    )
    return logging.getLogger("rich")
